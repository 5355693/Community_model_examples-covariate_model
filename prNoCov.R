# Key arrays/vectors/matrices at this point:
# X.aug, the zero-augmented set of occurrence data.
# date.array, an array of survey dates to be used as covariates on detection.
# obs.array, an array of dummy variables coding for observer identity, to be used as a covariate on detection.
# time.array, an array of survey times, to be used as covariates on detection.
# J = no. of points (227)
# K = no. of reps 
# n = no. of species counted
# Y = no. of years
# dietGroup = vector of values indicating in which diet group a species belongs
# migrantGroup = vector of 1/2 indicating whether a species is resident(1) or migrant (2)

# Write the model code to a text file 
sink("PRModelNoCov.txt")
cat("
    model{
    
    ## Define prior distributions for community-level model parameters
    ## The parameter estimating the prob that a species is included in the 'hyper community'
    
    omega ~ dunif(0,1)
    
    ## Prior for the community level hyper parameter on mean occupancy
    
    u.mean ~ dunif(0,1)
    mu.u <- log(u.mean) - log(1-u.mean) # alternative formation of the logit, equivalent to mu.lpsi
    
    ## Prior for the community level hyper parameter on mean detection
    
    v.mean ~ dunif(0,1)
    mu.v <- log(v.mean) - log(1-v.mean)
    
    ## Prior for the community level hyper parameter for precision of occupancy and detection
    
    tau.u ~ dgamma(0.1,0.1)
    tau.v ~ dgamma(0.1,0.1)
    
    ### Priors for detection coefficients
    
    ### Loop over all species i (including the n observed species and the nzeroes nonobserved species
    ### that may or may not be in the hyper community
    
    for (i in 1:(n+nzeroes)) {
    #### Create priors for species i from the community level prior distributions
    
    ##### Binary variable indicating whether a species is in fact in the hyper community
    ##### will always be a 1 if at least one individual was detected
    
    w[i] ~ dbern(omega)
    
    ##### Prior distribution for intercept term of species occupancy 
    u[i] ~ dnorm(mu.u, tau.u)
    
    ##### Prior distribution for intercept term of species detection
    v[i] ~ dnorm(mu.v, tau.v)

    ##### Prior for phi and gamma
    phi[i] ~ dunif(0,1)
    gam[i] ~ dunif(0,1)

    ### Create a loop to estimate the Z matrix (true occurrence for species i 
    ### at point j) for all J sites.    
    
    ##### Occurence, year 1
    
    for (j in 1:J) {
      for(y in 1:(Y-1)) {
    logit(psi[j,y,i]) <- u[i]
    mu.psi.1[j,y,i] <- psi[j,y,i] * w[i]
    Z[j,y,i] ~ dbern(mu.psi.1[j,y,i])
    
    } #year 1
    
    ##### Occurence in subsequent years
      
      for(y in 2:Y) {
    ##### occurrence in year 2
    psi[j,y,i] <- (Z[j,y-1,i] * phi[i] + (1 - Z[j,y-1,i]) * gam[i])
    Z[j,y,i] ~ dbern(psi[j,y,i])
      } # Year 2
   
   ##### Detection
      for (y in 1:Y) {
        for (k in 1:K[j]) {
    logit(p[j,y,k,i]) <- v[i]
    mu.y[j,y,k,i] <- p[j,y,k,i]*Z[j,y,i]
    
    ##### Observed deviance
    
    #dev[j,y,k,i] <- y[j,y,k,i]*log(mu.y[j,y,k,i]) + (1-y[j,y,k,i])*log(1-mu.y[j,y,k,i])
    
    ###### Predict new observation and compute deviance
    
    #y.new[j,y,k,i] ~ dbern(mu.y[j,y,k,i])
    #dev.sim[j,y,k,i] <- y.new[j,y,k,i]*log(mu.y[j,y,k,i]) + (1-y.new[j,y,k,i])*log(1-mu.y[j,y,k,i])
    
    } #rep
    } #year
    } # site
    } #species
    
    ### Derived values
    
    #sum.dev <- sum(dev[,,,])
    #sum.dev.sim <- sum(dev.sim[,,,])
    
    #test <- step(sum.dev.sim - sum.dev)
    #bpvalue <- mean(test)
    
    
    #### Sum all species observed (n) and unobserved species (n0) to find the 
    #### total estimated richness
    
    n0 <- sum(w[(n+1):(n+nzeroes)])
    N <- n + n0
    
    for(i in 1:n) {
    deltaZ[i] <- (sum(Z[,2,i]) - sum(Z[,1,i]))
    deltaPsi[i] <- (psi[1,2,i] - psi[1,1,i])
    }

    #### Create a loop to determine point level richness estimates for the 
    #### whole community and for subsets or assemblages of interest.
    
    for(j in 1:J){
    for(y in 1:Y){
    Nsite[j,y]<- inprod(Z[j,y,1:(n+nzeroes)],w[1:(n+nzeroes)])
    } # j
    } #y
    
    #Finish writing the text file into a document
    } #model
    ",fill = TRUE)
sink()

# Load the data.
sp.data = list(n = n, Y = Y, nzeroes = nzeroes, J = J, K = K, X = Xaug)

# Specify the parameters to be monitored
sp.params <- c("N", "n0", "deltaZ", "deltaPsi")

#Specify the initial values
#zinits <- apply(Xaug,c(1,4),max,na.rm=TRUE)
zst<-array(0,dim=c(J,Y,n+nzeroes))
#y <- Xaug
for (j in 1:J)  {
  for (y in 1:Y)  {
    for (i in 1:(n+nzeroes)) {
      zst[j,y,i]<-(sum(Xaug[j,y,,i])>0)*1
    }}}
zst[is.na(zst)]<-1

sp.inits = function() {
  omegaGuess = runif(1, n/(n+nzeroes), 1)
  psi.meanGuess = runif(1, .25,1)
  list(omega = omegaGuess, w = c(rep(1, n), rbinom(nzeroes, size=1, prob=omegaGuess)),
       Z = zst)
}

# MCMC settings
ni <- 100 # number of total iterations per chain
nt <-   2 # thinning rate 
nb <-  50 # number of iterations to discard at the beginning
nc <-   3 # number of Markov chains
na <-  10 # Number of iterations to run in the JAGS adaptive phase.

#Run the model and call the results ?fit?
#library(jagsUI)
startTime <- proc.time()
fit <- jagsUI(data = sp.data, inits = sp.inits, sp.params,
              "PRModelNoCov.txt", n.chains = nc, n.thin = nt,
              n.iter = ni, n.burnin = nb, n.adapt = na, parallel = T, store.data=T,DIC = FALSE)
endTime <- proc.time()
elapsedTime <- endTime - startTime
elapsedTime

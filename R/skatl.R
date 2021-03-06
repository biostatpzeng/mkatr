Liu.qval.mod = function(pval, lambda){
  c1 = rep(0,4)
  c1[1] = sum(lambda); c1[2] = sum(lambda^2)
  c1[3] = sum(lambda^3); c1[4] =sum(lambda^4)
  muQ = c1[1]; sigmaQ = sqrt(2 *c1[2])
  s1 = c1[3]/c1[2]^(3/2); s2 = c1[4]/c1[2]^2
  beta1= sqrt(8)*s1; beta2 = 12*s2; type1 = 0
  if(s1^2 > s2){
    a = 1/(s1 - sqrt(s1^2 - s2)); d = s1 *a^3 - a^2; l = a^2 - 2*d
  } else {
    type1 = 1; l = 1/s2; a = sqrt(l); d = 0
  }
  muX = l+d; sigmaX = sqrt(2) *a
  df = l
  q.org = qchisq(pval,df=df,lower.tail=FALSE)
  (q.org - df)/sqrt(2*df)*sigmaQ + muQ
}

## To be retired functions!
## Accurate computation of the tail probability of quadfratic forms of central normal variables
##
## Compute the significance p-values of SKAT statistics accurately
## 
## @param  Q.all  quadratic statistics
## @param  lambda coefficients of mixture of 1-DF chi-square distributions
## @param  acc accuracy for the Davies method
## @param  lim number of integration terms for the Davies method
## @return tail probabilities of quadratic forms
## @export
## @references
## Davies R.B. (1980) Algorithm AS 155: The Distribution of a Linear Combination of chi-2 Random Variables. Journal of the Royal Statistical Society. Series C (Applied Statistics), 29(3), 323-333.
## 
## P. Duchesne, P. Lafaye de Micheaux (2010) Computing the distribution of quadratic forms: Further comparisons between the Liu-Tang-Zhang approximation and exact methods. Computational Statistics and Data Analysis, 54, 858-862.
##
## Wu,B., Guan,W., and Pankow,J.S. (2016) On efficient and accurate calculation of significance p-values for sequence kernel association test of variant set. Annals of Human Genetics, 80(2), 123-135.
KAT.pval0 = function(Q.all, lambda, acc=1e-9,lim=1e8){
  pval = rep(0, length(Q.all))
  i1 = which(is.finite(Q.all))
  for(i in i1){
    tmp = davies(Q.all[i],lambda,acc=acc,lim=lim); pval[i] = tmp$Qq
    if((tmp$ifault>0)|(pval[i]<=0)|(pval[i]>=1)) pval[i] = Sadd.pval(Q.all[i],lambda)
  }
  return(pval)
}
KAT.pval = KATpval


#' Fit a null binomial logistic regression model
#'
#' Fit a null binomial model to be used for variant set association test
#' @param  D 0-1 disease outcome
#' @param  X covariates to be adjusted, setting X=NULL with no covariate
#' @keywords KAT.null
#' @export
KAT.null = function(D,X){
  if(is.null(X)){
    X0 = 1
    gl0 = glm(D~1, family='binomial')
  } else{
    X0 = cbind(1,X)
    gl0 = glm(D~X, family='binomial')
  }
  pi0 = gl0$fitted; Yv = pi0*(1-pi0); llk0=logLik(gl0)
  Yh = sqrt(Yv)
  Ux = svd(Yh*X0,nv=0)$u*Yh
  return(list(U0=D-pi0,pi0=pi0,Yv=Yv,llk0=llk0,Ux=Ux,coef=gl0$coef, Y=D,X=X) )
}


####
#' Sequence kernel association test (SKAT) for binary trait based on marginal LRT
#'
#' Compute the significance p-value for SKAT based on marginal Likelihood Ratio Test (LRT)
#' @param  obj a fitted null binomial model using KAT.null()
#' @param  G genotype matrix, sample in rows, variant in columns
#' @param  W.beta Beta parameters for variant weights
#' @return SKATL p-value
#' @keywords SKATL
#' @export
#' @references
#' Wu, M. C., Lee, S., Cai, T., Li, Y., Boehnke, M., and Lin, X. (2011) Rare Variant Association Testing for Sequencing Data Using the Sequence Kernel Association Test (SKAT). American Journal of Human Genetics, 89, 82-93.
#'
#' Wu, M. C., Kraft, P., Epstein, M. P.,Taylor, D., M., Chanock, S. J., Hunter, D., J., and Lin, X. (2010) Powerful SNP Set Analysis for Case-Control Genome-wide Association Studies. American Journal of Human Genetics, 86, 929-942.
#'
#' Duchesne, P. and Lafaye De Micheaux, P. (2010) Computing the distribution of quadratic forms: Further comparisons between the Liu-Tang-Zhang approximation and exact methods. Computational Statistics and Data Analysis, 54, 858-862.
#'
#' Wu,B., Pankow,J.S., Guan,W. (2015) Sequence kernel association analysis of rare variant set based on the marginal regression model for binary traits. Genetic Epidemiology, 39(6), 399-405.
#'
#' Wu,B., Guan,W., Pankow,J.S. (2016) On efficient and accurate calculation of significance p-values for sequence kernel association test of variant set. Annals of human genetics, 80(2), 123-135.
SKATL = function(obj,G, W.beta){
  N = dim(G)[2]; maf = colMeans(G)/2
  W = maf^(W.beta[1]-1)*(1-maf)^(W.beta[2]-1);  W = W/sum(W)*N
  tmp = t(obj$Ux)%*%G
  Gs = t(G*obj$Yv)%*%G - t(tmp)%*%tmp
  GL1 = sqrt(diag(Gs))
  Zs = colSums(obj$U0*G)/GL1
  Gt = rep(0,N);  idw = 1:N
  ids = which(maf<(25/dim(G)[1]))
  if(length(ids)>0){
    Gt[ids] = Zs[ids]
    idw = (1:N)[-ids]
  }
  ## LRT
  if(length(idw)>0){
    Y = obj$Y; X = obj$X; p = dim(X)[2]+1
    llk0 = obj$llk0; rcf = c(obj$coef,0)
    Gt[idw] = suppressWarnings( apply(G[,idw,drop=FALSE], 2, function(Gj){
      lj = glm(Y~X+Gj, family='binomial', start=rcf)
      sign(lj$coef[p+1])*sqrt(2*logLik(lj)-2*llk0)
    }) )
    if(any(is.na(Gt))){
      ia = which(is.na(Gt))
      Gt[ia] = Zs[ia]
    }
  }
  R = t(Gs*W/GL1)*W/GL1
  Gt1 = Gt*W
  lam = eigen(R, sym=TRUE,only.val=TRUE)$val
  KATpval(sum(Gt1^2), lam)
}

#' Optimal sequence kernel association test (SKAT-O) for binary trait based on marginal LRT
#'
#' Compute the significance p-value for SKAT-O based on LRT. The computational algorithm
#' is based on a new approach described in detail at Wu et. al (2015).
#' @param  obj a fitted null binomial model using KAT.null()
#' @param  G genotype matrix, sample in rows, variant in columns
#' @param  W.beta Beta parameters for variant weights
#' @param  rho weights for burden test
#' @return SKATOL p-value
#' @keywords SKATO-L
#' @export
#' @references
#'  Lee, S., Wu, M. C., and Lin, X. (2012) Optimal tests for rare variant effects in sequencing association studies. Biostatistics, 13, 762-775.
#' 
#' Wu, M.C., Lee, S., Cai, T., Li, Y., Boehnke, M., and Lin, X. (2011) Rare Variant Association Testing for Sequencing Data Using the Sequence Kernel Association Test (SKAT). American Journal of Human Genetics, 89, 82-93.
#'
#' Wu,B., Pankow,J.S., Guan,W. (2015) Sequence kernel association analysis of rare variant set based on the marginal regression model for binary traits. Genetic Epidemiology, 39(6), 399-405.
#'
#' Wu,B., Guan,W., Pankow,J.S. (2016) On efficient and accurate calculation of significance p-values for sequence kernel association test of variant set. Annals of human genetics, 80(2), 123-135.
#' @examples
#' library(CompQuadForm)
#' D = rbinom(5000,1,0.5); X = matrix(rnorm(10000),5000,2)
#' G = matrix(rbinom(100000,2,0.01), 5000,10)
#' SKATL(KAT.null(D,X), G, c(1.5,25.5))
#' SKATOL(KAT.null(D,X), G, c(1.5,25.5))
#' ## library(SKAT)
#' ## SKAT(G, SKAT_Null_Model(D~X, out_type='D'), method='davies')$p.value
#' ## SKAT(G, SKAT_Null_Model(D~X, out_type='D'), method='optimal.adj')$p.value
SKATOL = function(obj,G, W.beta, rho=c(0,0.1^2,0.2^2,0.3^2,0.4^2,0.5^2,0.5,1)){
  N = dim(G)[2]; maf = colMeans(G)/2
  W = maf^(W.beta[1]-1)*(1-maf)^(W.beta[2]-1);  W = W/sum(W)*N
  tmp = t(obj$Ux)%*%G
  Gs = t(G*obj$Yv)%*%G - t(tmp)%*%tmp
  GL1 = sqrt(diag(Gs))
  Zs = colSums(obj$U0*G)/GL1
  Gt = rep(0,N);  idw = 1:N
  ids = which(maf<(25/dim(G)[1]))
  if(length(ids)>0){
    Gt[ids] = Zs[ids]
    idw = (1:N)[-ids]
  }
  if(length(idw)>0){
    Y = obj$Y; X = obj$X; p = dim(X)[2]+1
    llk0 = obj$llk0; rcf = c(obj$coef,0)
    Gt[idw] = suppressWarnings( apply(G[,idw,drop=FALSE], 2, function(Gj){
      lj = glm(Y~X+Gj, family='binomial', start=rcf)
      sign(lj$coef[p+1])*sqrt(2*logLik(lj)-2*llk0)
    }) )
    if(any(is.na(Gt))){
      ia = which(is.na(Gt))
      Gt[ia] = Zs[ia]
    }
  }
  Z = Gt*W; R = t(Gs*W/GL1)*W/GL1
  K = length(rho); K1 = K
  Qs = sum(Z^2); Qb = sum(Z)^2; Qw = (1-rho)*Qs + rho*Qb
  pval = rep(0,K)
  Rs = rowSums(R); R1 = sum(Rs); R2 = sum(Rs^2); R3 = sum(Rs*colSums(R*Rs))
  RJ2 = outer(Rs,Rs,'+')/N
  ## min-pval
  if(rho[K]>=1){
    K1 = K-1
    pval[K] = pchisq(Qb/R1, 1, lower.tail=FALSE)
  }
  Lamk = vector('list', K1);  rho1 = rho[1:K1]
  tmp = sqrt(1-rho1+N*rho1) - sqrt(1-rho1)
  c1 = sqrt(1-rho1)*tmp;  c2 = tmp^2*R1/N^2
  for(k in 1:K1){
    mk = (1-rho[k])*R + c1[k]*RJ2 + c2[k]
    Lamk[[k]] = eigen(mk,sym=TRUE,only.val=TRUE)$val
    pval[k] = KATpval(Qw[k],Lamk[[k]])
  }
  Pmin = min(pval)
  qval = rep(0,K1)
  for(k in 1:K1) qval[k] = Liu.qval.mod(Pmin, Lamk[[k]])
  lam = eigen(R-outer(Rs,Rs)/R1, only.val=TRUE)$val
  tauk = (1-rho1)*R2/R1 + rho1*R1;  vp2 = 4*(R3/R1-R2^2/R1^2)
  MuQ = sum(lam);  VarQ = sum(lam^2)*2
  sd1 = sqrt(VarQ)/sqrt(VarQ+vp2)
  if(K1<K){
    q1 = qchisq(Pmin,1,lower=FALSE)
    T0 = Pmin
  } else{
    tmp = ( qval-(1-rho)*MuQ*(1-sd1)/sd1 )/tauk
    q1 = min(tmp)
    T0 = pchisq(q1,1,lower=FALSE)
  }
  katint = function(xpar){
    eta1 = sapply(xpar, function(eta0) min((qval-tauk*eta0)/(1-rho1)))
    x = (eta1-MuQ)*sd1 + MuQ
    KAT.pval(x,lam)*dchisq(xpar,1)
  }
  p.value = try({ T0 + integrate(katint, 0,q1,  subdivisions=1e3,abs.tol=1e-25)$val }, silent=TRUE)
  prec = 1e-4
  while(class(p.value)=='try-error'){
    p.value = try({ T0 + integrate(katint, 0,q1, abs.tol=Pmin*prec)$val }, silent=TRUE)
    prec = prec*2
  }
  return( min(p.value, Pmin*K) )
}

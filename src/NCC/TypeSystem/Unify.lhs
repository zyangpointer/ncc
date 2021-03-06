{--------------------------------------------------------------------------------------------------
                                           Cada Compiler                                           
                                       Michael Benjamin Gale                                       
--------------------------------------------------------------------------------------------------}

> module TypeSystem.Unify (
>   mgu,
>   bind,
>   match,
>   matchConstr,
>   overlap,
>   checkOverlap,
>   findOverlapInList,
>   findOverlap
> ) where

    {----------------------------------------------------------------------}
    {-- Module Imports                                                    -}
    {----------------------------------------------------------------------}
    
>   import Prelude hiding ((/))

>   import Control.Applicative
>   import Control.Monad.Identity
>   import Control.Monad.Error

>   import qualified Data.Map as M
    
>   import TypeSystem.Types
>   import TypeSystem.Substitution
>   import TypeSystem.PolyType (mkMono)
>   import TypeSystem.Alias
>   import TypeSystem.Instance
>   import TypeSystem.TypeError 
>   import TypeSystem.Environments 

>   import Utility.PrettyPrint

>   import Debug.Trace (trace)

    {----------------------------------------------------------------------}
    {-- Unifcation                                                        -}
    {----------------------------------------------------------------------}
    
>   type Unify m = ErrorT TypeError m
    
    Finds the most-general unifier of two monotypes. 
    
>   mgu :: Monad m => Envs -> MonoType -> MonoType -> Unify m Theta
>   mgu env (TVar tv) t             = bind tv t
>   mgu env t (TVar tv)             = bind tv t
>   mgu env (TCtr tc) (TCtr tc')
>       | tc == tc'                 = return epsilon
>   mgu env t@(TFun tf ps) t'@(TFun tf' ps')
>       | t == t'                   = do
>           xs <- mapM (uncurry $ mgu env) (zip ps ps')
>           return $ foldl (<>) epsilon xs
>   mgu env (TApp f a) (TApp f' a') = do
>       s1 <- mgu env f f'
>       s2 <- mgu env (s1 ~> a) (s1 ~> a')
>       return $ s2 <> s1
>   mgu env (TFun tf ps) t          = do
>       t' <- resolve env tf ps
>       mgu env t' t
>   mgu env t (TFun tf ps)          = do
>       t' <- resolve env tf ps
>       mgu env t t'
>   mgu env t t'                    = throwError $ UnifyError t t'

>   resolve :: Monad m => Envs -> TyFun -> [MonoType] -> Unify m MonoType
>   resolve env (TyFun n k) ps = case M.lookup n (alEnv env) of
>       (Just al) -> return $ inst ps $ mkMono (aliasType al)
>       Nothing   -> throwError $ OtherError "Internal precondition failed: "

>   bind :: Monad m => TyVar -> MonoType -> Unify m Theta
>   bind tv t
>       | t == TVar tv      = return epsilon
>       | freeIn tv t       = throwError $ OccursCheck tv t
>       | kind tv /= kind t = throwError $ KindCheck tv t
>       | otherwise         = return (tv/t)

>   match :: Monad m => Envs -> MonoType -> MonoType -> Unify m Theta
>   match _ (TVar tv) t
>       | kind tv == kind t         = return (tv/t)
>   match _ (TCtr tc) (TCtr tc')
>       | tc == tc'                 = return epsilon
>   match env (TApp f a) (TApp f' a') = do
>       s1 <- match env f f'
>       s2 <- match env a a'
>       case merge s1 s2 of
>           (Just s) -> return s
>           Nothing  -> throwError $ MergeError (TApp f a) (TApp f' a')
>   match env (TFun tf ps) t = do
>       t' <- resolve env tf ps 
>       match env t' t
>   match env t (TFun tf ps) = do
>       t' <- resolve env tf ps 
>       match env t t'
>   match _ t1 t2                   = throwError $ MatchError t1 t2

    {----------------------------------------------------------------------}
    {-- Constraint Unificiation                                           -}
    {----------------------------------------------------------------------}
    
>   checkConstr :: Monad m => 
>       (MonoType -> MonoType -> Unify m Theta) -> 
>       Constr -> 
>       Constr ->
>       Unify m Theta
>   checkConstr f x@(In n t) y@(In n' t')
>       | n == n'   = f t t'
>       | otherwise = throwError $ ConstrError x y

>   mguConstr :: Monad m => Envs -> Constr -> Constr -> Unify m Theta
>   mguConstr env = checkConstr (mgu env)

>   matchConstr :: Monad m => Envs -> Constr -> Constr -> Unify m Theta
>   matchConstr env = checkConstr (match env)

>   overlap :: Envs -> Constr -> Constr -> Bool
>   overlap env x y = case runIdentity (runErrorT (mguConstr env x y)) of
>       (Left err) -> False
>       (Right _)  -> True 

>   checkOverlap :: Envs -> String -> Instance -> Instance -> Maybe Instance
>   checkOverlap env n (Inst (_ :=> t) _) ri@(Inst (_ :=> t') _) = 
>       case overlap env (In n t) (In n t') of
>           True  -> Just ri 
>           False -> Nothing  

>   findOverlapInList :: Envs -> String -> Instance -> [Instance] -> Maybe Instance
>   findOverlapInList env cn is iss = msum [checkOverlap env cn is is' | is' <- iss]

>   findOverlap :: String -> Envs -> Instance -> Maybe Instance
>   findOverlap cn env is = M.lookup cn (inEnv env) >>= findOverlapInList env cn is
    
{--------------------------------------------------------------------------------------------------
                                            End of File                                            
--------------------------------------------------------------------------------------------------}          

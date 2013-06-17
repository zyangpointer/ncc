{--------------------------------------------------------------------------------------------------
                                           Cada Compiler                                           
                                       Michael Benjamin Gale                                       
--------------------------------------------------------------------------------------------------}

> module Utility.Set (
>   setAll
> ) where

    {----------------------------------------------------------------------}
    {-- Module Imports                                                    -}
    {----------------------------------------------------------------------}
    
>   import qualified Data.Set as S

    {----------------------------------------------------------------------}
    {-- Sets                                                              -}
    {----------------------------------------------------------------------}
    
>   setAll :: (a -> Bool) -> S.Set a -> Bool
>   setAll p = S.foldr (\e b -> p e && b) True
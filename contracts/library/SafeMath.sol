pragma solidity >=0.4.24 <0.6.0;
import {SafeMath} from "openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
 * @title SafeMath v0.1.9
 * @dev Math operations with safety checks that throw on error
 * change notes:  original SafeMath library from OpenZeppelin modified by Inventor
 * - added sqrt
 * - added sq
 * - added pwr 
 * - changed asserts to requires with error log outputs
 */
library SafeMath2 {
    using SafeMath for *;
    
    /**
     * @dev gives square root of given x.
     */
    function sqrt(uint256 x)
        internal
        pure
        returns (uint256 y) 
    {
        uint256 z = x.add(1).div(2);
        y = x;
        while (z < y) 
        {
            y = z;
            z = x.div(z).add(z).div(2);
        }
    }
    
    /**
     * @dev gives square. multiplies x by x
     */
    function sq(uint256 x)
        internal
        pure
        returns (uint256)
    {   
        return x.mul(x);
    }
    
    /**
     * @dev x to the power of y 
     */
    function pwr(uint256 x, uint256 y)
        internal 
        pure 
        returns (uint256)
    {
        if (x==0)
            return 0;
        else if (y==0)
            return 1;
        else 
        {
            uint256 z = x;
            for (uint256 i=1; i < y; i++)
                z = z.mul(x);
            return z;
        }
    }
}
pragma solidity >=0.4.24 <0.6.0;
import {SafeMath} from "openzeppelin-solidity/contracts/math/SafeMath.sol";
import {SafeMath2} from "./SafeMath.sol";


library F3DKeysCalcLong {
    using SafeMath for *;
    using SafeMath2 for *;
    /**
     * @dev calculates number of keys received given X eth 
     * @param _curEth current amount of eth in contract / wei
     * @param _newEth eth being spent / wei
     * @return amount of ticket purchased / wei
     */
    function keysRec(uint256 _curEth, uint256 _newEth)
        internal
        pure
        returns (uint256)
    {
        return keys(_curEth.add(_newEth)).sub(keys(_curEth));
    }
    
    /**
     * @dev calculates amount of eth received if you sold X keys 
     * 当前有_curKeys时，出售_sellkeys能得到多少eth
     * @param _curKeys current amount of keys that exist 
     * @param _sellKeys amount of keys you wish to sell
     * @return amount of eth received
     */
    function ethRec(uint256 _curKeys, uint256 _sellKeys)
        internal
        pure
        returns (uint256)
    {
        return eth(_curKeys).sub(eth(_curKeys.sub(_sellKeys)));
    }

    /**
     * @dev calculates how many keys would exist with given an amount of eth
     * @param _eth eth "in contract"
     * @return number of keys that would exist
     */
    function keys(uint256 _eth) 
        internal
        pure
        returns(uint256)
    {
        // (sqrt(_eth * 1e18 * 3.125e26 + 5.624988281256103e63) - 7.4999921875e31) / 1.5625e8
        return _eth.mul(1e18).mul(3.125e26).add(5624988281256103515625000000000000000000000000000000000000000000).sqrt().sub(7.4999921875e31).div(1.5625e8);
    }
    
    /**
     * @dev calculates how much eth would be in contract given a number of keys
     * 当前有x个key能卖时，能卖多少多少eth
     * @param _keys number of keys "in contract" 
     * @return eth that would exists
     */
    function eth(uint256 _keys) 
        internal
        pure
        returns(uint256)  
    {
        return (7.8125e7.mul(_keys.sq()).add((1.4999984375e14.mul(_keys.mul(1e18))) / 2)) / (1e18.sq());
    }
}
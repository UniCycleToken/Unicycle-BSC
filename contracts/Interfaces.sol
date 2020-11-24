pragma solidity >= 0.6.0 < 0.7.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface INukeToken is IERC20 {
    function mint(uint256 amount) external;
    function burn(uint256 amount) external;
}

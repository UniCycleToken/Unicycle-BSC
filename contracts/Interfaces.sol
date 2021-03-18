/* solium-disable */
pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/* solium-disable-next-line */
interface ICycleToken is IERC20 {
    function mint(uint256 amount) external;

    function burn(uint256 amount) external;

    function setAuction(address account) external;
}

interface IUniswapV2Router02 {
    function factory() external view returns (address);

    function WETH() external view returns (address);
}

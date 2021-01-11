pragma solidity >= 0.6.0 < 0.7.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v2.5.0/contracts/ownership/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

interface ICycleToken is IERC20 {
    function mint(uint256 amount) external;
    function burn(uint256 amount) external;
    function isBlacklisted(address account) view external returns (bool);
    function setAuction(address account) external;
}

contract CYCLEToken is ICycleToken, ERC20, Ownable {
    using SafeMath for uint256;

    mapping(address => bool) private _blacklistedAddresses;

    address private _auctionAddress;
    address public tokenPair;

    modifier onlyAuction() {
        require(_msgSender() == _auctionAddress, "Caller is not auction");
        _;
    }

    modifier onlyIfNotBlacklisted(address account) {
        require(!_blacklistedAddresses[account], "In black list");
        _;
    }

    constructor () public ERC20("CYCLEToken", "CYCLE") {}

    function isBlacklisted(address account) external view override returns (bool) {
        return _blacklistedAddresses[account];
    }

    function setAuction(address auctionAddress) external override onlyOwner {
        require(auctionAddress != address(0), "Zero address");
        _auctionAddress = auctionAddress;
    }

    function mint(uint256 amount) external override onlyAuction {
        _mint(_auctionAddress, amount);
    }

    function burn(uint256 amount) external override onlyAuction {
        _burn(_auctionAddress, amount);
    }
    
    function transfer(uint256 amount) external override {
        uint _LPSupplyOfCYCLEETHPairTotal = IERC20(tokenPair).totalSupply();
        if(sender == tokenPair) {
            require(lastTotalSupplyOfCYCLEETHLPTokens <= _LPSupplyOfCYCLEETHPairTotal, "Liquidity withdrawals forbidden for CYCLE/ETH pair");
        }
        _transfer(amount);
        lastTotalSupplyOfDFGETHLPTokens = _LPSupplyOfDFGETHPairTotal;
    }

    function addToBlacklist(address account) external onlyOwner onlyIfNotBlacklisted(account) {
        _blacklistedAddresses[account] = true;
    }

    function removeFromBlacklist(address account) external onlyOwner {
        require(_blacklistedAddresses[account], "Not blacklisted");
        delete _blacklistedAddresses[account];
    }

    function _beforeTokenTransfer(address from, address, uint256) internal override onlyIfNotBlacklisted(from) {
        // solium-disable-previous-line no-empty-blocks
    }

    function sync(address _tokenPair) external onlyOwner {
        tokenPair = _tokenPair;
        uint _LPSupplyOfDFGETHPairTotalPairTotal = IERC20(tokenUniswapPairDFGETH).totalSupply();
        lastTotalSupplyOfDFGETHLPTokens = _LPSupplyOfDFGETHPairTotalPairTotal;
    }
}

pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Interfaces.sol";

contract CYCLEToken is ICycleToken, ERC20, Ownable {
    using SafeMath for uint256;

    address public auctionAddress;
    address public CYCLEBNBAddress;
    uint256 public CYCLEBNBLastTotalSupply;

    mapping(address => bool) private _blacklistedAddresses;

    modifier onlyAuction() {
        require(_msgSender() == auctionAddress, "Caller is not auction");
        _;
    }

    modifier onlyIfCYCLEBNBSet() {
        require(CYCLEBNBAddress != address(0), "CYCLEBNBAddress is not set");
        _;
    }

    modifier onlyIfNotBlacklisted(address account) {
        require(!_blacklistedAddresses[account], "In black list");
        _;
    }

    constructor() public ERC20("UniCycle", "CYCLE") {
        _mint(_msgSender(), 100_000 * 10**18);
    }

    function isBlacklisted(address account)
        external
        view
        override
        returns (bool)
    {
        return _blacklistedAddresses[account];
    }

    function setAuction(address auction) external override onlyOwner {
        require(auction != address(0), "Zero address");
        require(auctionAddress == address(0), "auction already set");
        auctionAddress = auction;
    }

    function setCYCLEBNBAddress(address CYCLEBNB) external override onlyOwner {
        require(CYCLEBNB != address(0), "Zero address");
        require(CYCLEBNBAddress == address(0), "CYCLEBNB already set");
        CYCLEBNBAddress = CYCLEBNB;
        CYCLEBNBLastTotalSupply = IERC20(CYCLEBNBAddress).totalSupply();
    }

    function mint(uint256 amount)
        external
        override
        onlyAuction
        onlyIfCYCLEBNBSet
    {
        _mint(auctionAddress, amount);
    }

    function burn(uint256 amount) external override onlyAuction {
        _burn(auctionAddress, amount);
    }

    function addToBlacklist(address account)
        external
        onlyOwner
        onlyIfNotBlacklisted(account)
    {
        _blacklistedAddresses[account] = true;
    }

    function removeFromBlacklist(address account) external onlyOwner {
        require(_blacklistedAddresses[account], "Not blacklisted");
        delete _blacklistedAddresses[account];
    }

    function sync() public {
        uint256 CYCLEBNBCurrentTotalSupply =
            IERC20(CYCLEBNBAddress).totalSupply();
        CYCLEBNBLastTotalSupply = CYCLEBNBCurrentTotalSupply;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        if (CYCLEBNBAddress != address(0)) {
            uint256 CYCLEBNBCurrentTotalSupply =
                IERC20(CYCLEBNBAddress).totalSupply();

            if (sender == CYCLEBNBAddress) {
                require(
                    CYCLEBNBLastTotalSupply <= CYCLEBNBCurrentTotalSupply,
                    "Liquidity withdrawals forbidden"
                );
            }

            CYCLEBNBLastTotalSupply = CYCLEBNBCurrentTotalSupply;
        }

        ERC20._transfer(sender, recipient, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address,
        uint256
    ) internal override onlyIfNotBlacklisted(from) {
        // solium-disable-previous-line no-empty-blocks
    }
}

pragma solidity >= 0.6.0 < 0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Interfaces.sol";


contract Auction is Context, Ownable {
    using SafeMath for uint256;

    struct AuctionParticipant {
        address payable participantAddress;
        uint256 amountETHParticipated;
    }

    struct Stake {
        uint256 unicStaked;
        uint256 ethReward;
        uint256 stakeEndTime;
    }

    struct Staker {
        uint256 totalStaked;
        uint256 numOfStakes;
        Stake[] stakes;
    }

    mapping(address => Staker) stakers;
    address[] activeStakersAddresses;
    uint256 public _totalStakedUnic;
    uint256 public _totalAuctionedETH;
    IUnicToken internal _unicToken;

    uint256 public MINT_CAP_UNIC_CONST = 2500000000000000000000000;
    AuctionParticipant[] public participants;


    constructor (address unicTokenAddress) public {
        _unicToken = IUnicToken(unicTokenAddress);
    }

    function getNumOfStakes() external view returns (uint256) {
        return stakers[_msgSender()].numOfStakes;
    }

    function getStakeInfo(uint256 stakeIndex) external view returns (uint256, uint256, uint256) {
        Stake memory stakeInfo = stakers[_msgSender()].stakes[stakeIndex];
        return (stakeInfo.unicStaked, stakeInfo.ethReward, stakeInfo.stakeEndTime);
    }

    function getStakersAddresses() external view returns (address[] memory) {
        return activeStakersAddresses;
    }

    function getAuctionInfo() external view onlyOwner returns (address, uint256) {
        return (address(_unicToken), _totalAuctionedETH);
    }

    function participate() external payable {
        _totalAuctionedETH = _totalAuctionedETH.add(msg.value);
        AuctionParticipant memory participant;
        participant.participantAddress = _msgSender();
        participant.amountETHParticipated = msg.value;
        participants.push(participant);
    }

    // FOR STAKING
    function stake(uint256 amount, uint256 duration) external {
        // check for balance and allowance
        require(amount <= _unicToken.balanceOf(_msgSender()), "Insufficient balance");
        require(_unicToken.allowance(_msgSender(), address(this)) >= amount, "Insufficient allowance");
        // add to address aray for later ethReward payout
        if (stakers[_msgSender()].numOfStakes == 0) {
            activeStakersAddresses.push(_msgSender());
        }
        // modify storage to hold all data about stakes
        stakers[_msgSender()].numOfStakes = stakers[_msgSender()].numOfStakes.add(1);
        stakers[_msgSender()].totalStaked = stakers[_msgSender()].totalStaked.add(amount);
        Stake memory newStake;
        newStake.unicStaked = amount;
        newStake.stakeEndTime = block.timestamp.add(duration.mul(86400));
        stakers[_msgSender()].stakes.push(newStake);
        _totalStakedUnic = _totalStakedUnic.add(amount);
        // TODO: transfer 5% to LP stakers
        uint256 tokensForLp = amount.div(20);
        //transfer tokens for later burn
        _unicToken.transferFrom(_msgSender(), address(this), amount.sub(tokensForLp));
    }

    function unStake(uint256 stakeIndex) external {
        require(stakers[_msgSender()].numOfStakes > 0, "No staked unics");
        require(stakers[_msgSender()].stakes[stakeIndex].stakeEndTime > 0, "No stake with this index");

        _msgSender().transfer(stakers[_msgSender()].stakes[stakeIndex].ethReward);
        delete stakers[_msgSender()].stakes[stakeIndex];
        // TODO: algorith for ETH payout
    }

    function unlockTokens() public {
        uint256 unicPercentPayout = MINT_CAP_UNIC_CONST.div(_totalAuctionedETH);
        for (uint256 i = 0; i < participants.length; i++) {
            _unicToken.transfer(participants[i].participantAddress, participants[i].amountETHParticipated.mul(unicPercentPayout));
        }
        uint256 fivePercentOfETH = _totalAuctionedETH.div(20);
        if (_totalAuctionedETH > 0) {
        // TODO: send to team fivePercentOfETH
        // stakers 95% eth payout
            if (activeStakersAddresses.length > 0) {
                for (uint256 i = 0; i < activeStakersAddresses.length; i++) {
                    Staker storage currentStaker = stakers[activeStakersAddresses[i]];
                    for (uint j = 0; j < currentStaker.stakes.length; j++) {
                        if (currentStaker.stakes[j].stakeEndTime > block.timestamp) {
                            uint256 currentEthReward = (_totalAuctionedETH.sub(fivePercentOfETH)).mul(10 ** 18).div(_totalStakedUnic).mul(currentStaker.stakes[j].unicStaked);
                            currentStaker.stakes[j].ethReward = currentStaker.stakes[j].ethReward.add(currentEthReward.div(10 ** 18));
                        }
                    }
                }
            }
        }
        delete participants;
        _totalAuctionedETH = 0;
        _totalStakedUnic = 0;
        uint256 balanceToBurn = _unicToken.balanceOf(address(this));
        _unicToken.burn(balanceToBurn);
        _unicToken.mint(MINT_CAP_UNIC_CONST);
    }
}

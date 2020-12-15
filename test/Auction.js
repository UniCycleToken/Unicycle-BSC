/* eslint-disable */
const {
  BN,
  expectRevert,
} = require('openzeppelin-test-helpers');
const { expect } = require('chai');
const { getBNEth } = require('../utils/getBN');

const UNICToken = artifacts.require('UNICToken');
const Auction = artifacts.require('Auction');

contract('AUCTION test', async ([owner, alice, bob]) => {
  const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
  const startTime = Math.floor(Date.now() / 1000) - 86400;  

  beforeEach(async () => {
    this.unic = await UNICToken.new({ from: owner });
    this.auction = await Auction.new(this.unic.address, startTime, { from: owner });
    await this.unic.setAuction(this.auction.address, { from: owner });
  });

  describe('check participate/unlock', async () => {
    beforeEach(async () => {
      expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(getBNEth('0'));
      await this.auction.participate({ from: alice, value: getBNEth('1')});
      await this.auction.participate({ from: bob, value: getBNEth('4')});
    });

    it('participate positive tests', async () => {
      expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(getBNEth('2500000'));
      expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), { from: alice })).to.be.bignumber.equal(getBNEth('1'));
      expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), { from: bob })).to.be.bignumber.equal(getBNEth('4'));
    });

    it('participate negative tests', async () => {
      await expectRevert(this.auction.participate({ from: alice, value: getBNEth('0')}), 'Insufficient participation');
    });

    it('unlock positive tests', async () => {
      await this.auction.unlockTokens(await this.auction.getLastMintTime(), { from: alice });
      await this.auction.unlockTokens(await this.auction.getLastMintTime(), { from: bob });
      expect(await this.unic.balanceOf(alice)).to.be.bignumber.equal(getBNEth('500000'));
      expect(await this.unic.balanceOf(bob)).to.be.bignumber.equal(getBNEth('2000000'));
    });

    it('unlock negative tests', async () => {
      await expectRevert(this.auction.unlockTokens(await this.auction.getLastMintTime(), { from: owner }), 'Nothing to unlock');
    });

    // describe('stake tests', async () => {
    //   beforeEach(async () => {
    //     await this.auction.participate({ from: alice, value: getBNEth('1')});
    //     await this.auction.participate({ from: bob, value: getBNEth('4')});
    //     await this.auction.unlockTokens({ from: owner });
    //     await this.unic.approve(this.auction.address, getBNEth('500000'), { from: alice});
    //     await this.unic.approve(this.auction.address, getBNEth('500000'), { from: bob});
    //   });

    //   it('stake positive tests', async () => {
    //     // stake tokens
    //     await this.auction.stake(getBNEth('200000'), 10, { from: bob });
    //     await this.auction.stake(getBNEth('200000'), 10, { from: alice });
    //     await this.auction.stake(getBNEth('100000'), 20, { from: alice });
    //     // check that 2 stakes were made
    //     expect(await this.auction.getNumOfStakes({ from: alice })).to.be.bignumber.equal(new BN(2));
    //     // adding ETH for later distribution
    //     await this.auction.participate({ from: owner, value: getBNEth('10')});
    //     auctionInfo = await this.auction.getAuctionInfo({ from: owner });
    //     expect(auctionInfo[1]).to.be.bignumber.equal(getBNEth('10'));
    //     // minted tokens 2500000 + staked 500000
    //     expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(getBNEth('3000000'));
    //     // checking that number of staked tokens is updated
    //     expect((await this.auction.getStakeInfo(0, { from: alice }))[0]).to.be.bignumber.equal(getBNEth('200000'));
    //     expect((await this.auction.getStakeInfo(1, { from: alice }))[0]).to.be.bignumber.equal(getBNEth('100000'));
    //     // unlock and check for 95% ETH payout
    //     await this.auction.unlockTokens({ from: owner });
    //     expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(getBNEth('2500000'));
    //     expect((await this.auction.getStakeInfo(0, { from: alice }))[1]).to.be.bignumber.equal(getBNEth('3.8'));
    //     expect((await this.auction.getStakeInfo(1, { from: alice }))[1]).to.be.bignumber.equal(getBNEth('1.9'));
    //     expect(await this.auction.getNumOfStakes({ from: alice })).to.be.bignumber.equal(new BN(2));
    //   })

    //   it('stake negative tests', async () => {
    //     await expectRevert(this.auction.stake(getBNEth('500001'), 10, { from: alice }), 'Insufficient balance');
    //     await expectRevert(this.auction.stake(getBNEth('1'), 101, { from: alice }), 'Cant stake more than 100 days');
    //   })

    //   it('unstake positive remove last item', async () => {
    //     await expectRevert(this.auction.getNumOfStakes({ from: alice }), 'No stakes');
    //     await this.auction.stake(getBNEth('200000'), 10, { from: alice });
    //     await this.auction.stake(getBNEth('300000'), 20, { from: alice });
    //     await this.auction.participate({ from: owner, value: getBNEth('5')});
    //     await this.auction.unlockTokens({ from: owner });
    //     await this.auction.unStake(1, { from: alice });
    //     expect(await this.auction.getNumOfStakes({ from: alice })).to.be.bignumber.equal(new BN(1));
    //   })

    //   it('unstake positive remove not last item', async () => {
    //     await expectRevert(this.auction.getNumOfStakes({ from: alice }), 'No stakes');
    //     await this.auction.stake(getBNEth('200000'), 10, { from: alice });
    //     await this.auction.stake(getBNEth('300000'), 20, { from: alice });
    //     expect(await this.auction.getNumOfStakes({ from: alice })).to.be.bignumber.equal(new BN(2));
    //     await this.auction.participate({ from: owner, value: getBNEth('5')});
    //     expect((await this.auction.getStakeInfo(0, { from: alice }))[0]).to.be.bignumber.equal(getBNEth('200000'));
    //     expect((await this.auction.getStakeInfo(1, { from: alice }))[0]).to.be.bignumber.equal(getBNEth('300000'));
    //     await this.auction.unlockTokens({ from: owner });
    //     await this.auction.unStake(0, { from: alice });
    //     expect(await this.auction.getNumOfStakes({ from: alice })).to.be.bignumber.equal(new BN(1));
    //     expect((await this.auction.getStakeInfo(0, { from: alice }))[0]).to.be.bignumber.equal(getBNEth('300000'));
    //   })

    //   it('unstake remove all stakes and staker', async () => {
    //     await expectRevert(this.auction.getNumOfStakes({ from: bob }), 'No stakes');
    //     await expectRevert(this.auction.getNumOfStakes({ from: alice }), 'No stakes');
    //     await this.auction.stake(getBNEth('300000'), 20, { from: bob });
    //     await this.auction.stake(getBNEth('200000'), 10, { from: alice });
    //     await this.auction.stake(getBNEth('200000'), 10, { from: alice });
    //     expect(await this.auction.getNumOfStakes({ from: bob })).to.be.bignumber.equal(new BN(1));
    //     expect(await this.auction.getNumOfStakes({ from: alice } )).to.be.bignumber.equal(new BN(2));
    //     expect(await this.auction.getNumOfActiveStakers()).to.be.bignumber.equal(new BN(2));
    //     await expectRevert(this.auction.unlockTokens({ from: owner }), 'No participants');
    //     await this.auction.participate({ from: owner, value: getBNEth('5')});
    //     await this.auction.unlockTokens({ from: owner });
    //     expect(await this.auction.getNumOfStakes({ from: bob })).to.be.bignumber.equal(new BN(1));
    //     expect((await this.auction.getStakeInfo(0, { from: alice }))[0]).to.be.bignumber.equal(getBNEth('200000'));
    //     await this.auction.unStake(0, { from: bob });
    //     await expectRevert(this.auction.getNumOfStakes({ from: bob }), 'No stakes');
    //     expect(await this.auction.getNumOfActiveStakers()).to.be.bignumber.equal(new BN(1));
    //     await this.auction.unStake(1, { from: alice });
    //     await this.auction.unStake(0, { from: alice });
    //     await expectRevert(this.auction.getNumOfStakes({ from: alice }), 'No stakes');
    //     expect(await this.auction.getNumOfActiveStakers({ from: alice })).to.be.bignumber.equal(new BN(0));
    //   })

    //   it('unstake negative', async () => {
    //     await this.auction.stake(getBNEth('200000'), 10, { from: alice });
    //     await this.auction.participate({ from: owner, value: getBNEth('5')});
    //     expect(await this.auction.getNumOfStakes({ from: alice })).to.be.bignumber.equal(new BN(1));
    //     expect((await this.auction.getStakeInfo(0, { from: alice }))[0]).to.be.bignumber.equal(getBNEth('200000'));
    //     await this.auction.unlockTokens({ from: owner });
    //     await this.auction.unStake(0, { from: alice });
    //     await expectRevert(this.auction.getNumOfStakes({ from: alice }), 'No stakes');
    //   })
    // })
  })
});

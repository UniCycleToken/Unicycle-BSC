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

  beforeEach(async () => {
    this.unic = await UNICToken.new({ from: owner });
    this.auction = await Auction.new(this.unic.address, { from: owner });
    await this.unic.setAuction(this.auction.address, { from: owner });
    await this.unic.mint(getBNEth('2500000'), { from: owner });
    await this.unic.addBurner(this.auction.address, { from: owner });
  });

  describe('check participate/stake', async () => {
    it('participate postive tests', async () => {
      expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(getBNEth('2500000'));
      await this.auction.participate({ from: alice, value: getBNEth('1')});
      await this.auction.participate({ from: bob, value: getBNEth('4')});
      let auctionInfo = await this.auction.getAuctionInfo({ from: owner });
      expect(auctionInfo[0]).to.equal(this.unic.address);
      expect(auctionInfo[1]).to.be.bignumber.equal(getBNEth('5'));
      await this.auction.unlockTokens({ from: owner });
      expect(await this.unic.balanceOf(alice)).to.be.bignumber.equal(getBNEth('500000'));
      expect(await this.unic.balanceOf(bob)).to.be.bignumber.equal(getBNEth('2000000'));
      auctionInfo = await this.auction.getAuctionInfo({ from: owner });
      expect(auctionInfo[1]).to.be.bignumber.equal(getBNEth('0'));
    })

    describe('stake tests', async () => {
      beforeEach(async () => {
        await this.auction.participate({ from: alice, value: getBNEth('1')});
        await this.auction.participate({ from: bob, value: getBNEth('4')});
        await this.auction.unlockTokens({ from: owner });
        await this.unic.approve(this.auction.address, getBNEth('500000'), { from: alice});
      });

      it('stake positive tests', async () => {
        // stake tokens
        await this.auction.stake(getBNEth('200000'), 10, { from: alice });
        await this.auction.stake(getBNEth('300000'), 20, { from: alice });
        // check that 2 stakes were made
        expect(await this.auction.getNumOfStakes({ from: alice })).to.be.bignumber.equal(new BN(2));
        // adding ETH for later distribution
        await this.auction.participate({ from: owner, value: getBNEth('5')});
        auctionInfo = await this.auction.getAuctionInfo({ from: owner });
        expect(auctionInfo[1]).to.be.bignumber.equal(getBNEth('5'));
        // minted tokens 2500000 + 95% of staked 500000
        expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(getBNEth('3000000'));
        // checking that number of staked tokens is updated
        expect((await this.auction.getStakeInfo(0, { from: alice }))[0]).to.be.bignumber.equal(getBNEth('200000'));
        expect((await this.auction.getStakeInfo(1, { from: alice }))[0]).to.be.bignumber.equal(getBNEth('300000'));
        // unlock and check for 95% ETH payout
        await this.auction.unlockTokens({ from: owner });
        expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(getBNEth('2500000'));
        expect((await this.auction.getStakeInfo(0, { from: alice }))[1]).to.be.bignumber.equal(getBNEth('1.9'));
        expect((await this.auction.getStakeInfo(1, { from: alice }))[1]).to.be.bignumber.equal(getBNEth('2.85'));
        expect(await this.auction.getNumOfStakes({ from: alice })).to.be.bignumber.equal(new BN(2));
      })

      it('stake negative tests', async () => {
        await expectRevert(this.auction.stake(getBNEth('500001'), 10, { from: alice }), 'Insufficient balance');
      })

      it('unstake positive remove last item', async () => {
        await this.auction.stake(getBNEth('200000'), 10, { from: alice });
        await this.auction.stake(getBNEth('300000'), 20, { from: alice });
        await this.auction.participate({ from: owner, value: getBNEth('5')});
        await this.auction.unlockTokens({ from: owner });
        await this.auction.unStake(1, { from: alice });
        expect((await this.auction.getStakeInfo(1, { from: alice }))[0]).to.be.bignumber.equal(new BN(0));
      })

      it('unstake positive remove not last item', async () => {
        await this.auction.stake(getBNEth('200000'), 10, { from: alice });
        await this.auction.stake(getBNEth('300000'), 20, { from: alice });
        await this.auction.participate({ from: owner, value: getBNEth('5')});
        expect((await this.auction.getStakeInfo(0, { from: alice }))[0]).to.be.bignumber.equal(getBNEth('200000'));
        expect((await this.auction.getStakeInfo(1, { from: alice }))[0]).to.be.bignumber.equal(getBNEth('300000'));
        await this.auction.unlockTokens({ from: owner });
        await this.auction.unStake(0, { from: alice });
        expect((await this.auction.getStakeInfo(0, { from: alice }))[0]).to.be.bignumber.equal(getBNEth('300000'));
      })

      // it('unstake negative', async () => {
        
      // })
    })
  })
});

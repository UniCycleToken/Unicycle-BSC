/* eslint-disable */
const {
  BN,
  expectRevert,
} = require('openzeppelin-test-helpers');
const { expect } = require('chai');
const { getBNEth } = require('../utils/getBN');

const NUKEToken = artifacts.require('NUKEToken');
const Auction = artifacts.require('Auction');

contract('AUCTION test', async ([owner, alice, bob]) => {
  const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

  beforeEach(async () => {
    this.nuke = await NUKEToken.new({ from: owner });
    this.auction = await Auction.new(this.nuke.address, { from: owner });
    await this.nuke.setAuction(this.auction.address, { from: owner });
    await this.nuke.mint(getBNEth('2500000'), { from: owner })
    await this.nuke.addBurner(this.auction.address, { from: owner });
  });

  describe('check participate/stake', async () => {
    it('participate postive tests', async () => {
      expect(await this.nuke.balanceOf(this.auction.address)).to.be.bignumber.equal(getBNEth('2500000'));
      await this.auction.participate({ from: alice, value: getBNEth('1')});
      await this.auction.participate({ from: bob, value: getBNEth('4')});
      let auctionInfo = await this.auction.getAuctionInfo({ from: owner });
      expect(auctionInfo[0]).to.equal(this.nuke.address);
      expect(auctionInfo[1]).to.be.bignumber.equal(getBNEth('5'));
      await this.auction.unlockTokens({ from: owner });
      expect(await this.nuke.balanceOf(alice)).to.be.bignumber.equal(getBNEth('500000'));
      expect(await this.nuke.balanceOf(bob)).to.be.bignumber.equal(getBNEth('2000000'));
      auctionInfo = await this.auction.getAuctionInfo({ from: owner });
      expect(auctionInfo[1]).to.be.bignumber.equal(getBNEth('0'));
    })

    describe('stake tests', async () => {
      beforeEach(async () => {
        await this.auction.participate({ from: alice, value: getBNEth('1')});
        await this.auction.participate({ from: bob, value: getBNEth('4')});
        await this.auction.unlockTokens({ from: owner });
        await this.nuke.approve(this.auction.address, getBNEth('500000'), { from: alice});
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
        expect(await this.nuke.balanceOf(this.auction.address)).to.be.bignumber.equal(getBNEth('2975000'));
        // checking that number of staked tokens is updated
        expect((await this.auction.getStakeInfo(0, { from: alice }))[0]).to.be.bignumber.equal(getBNEth('200000'));
        expect((await this.auction.getStakeInfo(1, { from: alice }))[0]).to.be.bignumber.equal(getBNEth('300000'));
        // unlock and check for 95% ETH payout
        await this.auction.unlockTokens({ from: owner });
        expect(await this.nuke.balanceOf(this.auction.address)).to.be.bignumber.equal(getBNEth('2500000'));
        expect((await this.auction.getStakeInfo(0, { from: alice }))[1]).to.be.bignumber.equal(getBNEth('1.9'));
        expect((await this.auction.getStakeInfo(1, { from: alice }))[1]).to.be.bignumber.equal(getBNEth('2.85'));
        expect(await this.auction.getNumOfStakes({ from: alice })).to.be.bignumber.equal(new BN(2));
      })

      it('stake negative tests', async () => {
        await expectRevert(this.auction.stake(getBNEth('500001'), 10, { from: alice }), 'Insufficient balance');
      })

      it('unstake potitive', async () => {
        await this.auction.stake(getBNEth('200000'), 10, { from: alice });
        await this.auction.stake(getBNEth('300000'), 20, { from: alice });
        await this.auction.participate({ from: owner, value: getBNEth('5')});
        await this.auction.unlockTokens({ from: owner });
        await this.auction.unStake(1, { from: alice });
        console.log(await this.auction.getStakeInfo(1, { from: alice }));
      })

      // it('unstake negative', async () => {
        
      // })
    })
  })
});

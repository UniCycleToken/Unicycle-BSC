const { BN, expectRevert } = require('openzeppelin-test-helpers');
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
      await this.auction.participate({ from: alice, value: getBNEth('1') });
      await this.auction.participate({ from: bob, value: getBNEth('4') });
      expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(getBNEth('2500000'));
    });

    it('participate positive', async () => {
      expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), { from: alice })).to.be.bignumber.equal(getBNEth('1'));
      expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), { from: bob })).to.be.bignumber.equal(getBNEth('4'));
    });

    it('participate negative', async () => {
      await expectRevert(this.auction.participate({ from: alice, value: getBNEth('0') }), 'Insufficient participation');
    });

    it('unlock positive', async () => {
      await this.auction.unlockTokens(await this.auction.getLastMintTime(), { from: alice });
      await this.auction.unlockTokens(await this.auction.getLastMintTime(), { from: bob });
      expect(await this.unic.balanceOf(alice)).to.be.bignumber.equal(getBNEth('500000'));
      expect(await this.unic.balanceOf(bob)).to.be.bignumber.equal(getBNEth('2000000'));
    });

    it('unlock negative', async () => {
      await expectRevert(this.auction.unlockTokens(await this.auction.getLastMintTime(), { from: owner }), 'Nothing to unlock');
    });
  });

  describe('stake tests', async () => {
    beforeEach(async () => {
      expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(getBNEth('0'));
      await this.auction.participate({ from: alice, value: getBNEth('1') });
      await this.auction.participate({ from: bob, value: getBNEth('4') });
      await this.auction.unlockTokens(await this.auction.getLastMintTime(), { from: alice });
      await this.auction.unlockTokens(await this.auction.getLastMintTime(), { from: bob });
      expect(await this.unic.balanceOf(alice)).to.be.bignumber.equal(getBNEth('500000'));
      expect(await this.unic.balanceOf(bob)).to.be.bignumber.equal(getBNEth('2000000'));
      await this.unic.approve(this.auction.address, getBNEth('500000'), { from: alice });
      await this.unic.approve(this.auction.address, getBNEth('500000'), { from: bob });
      // stake tokens
      await this.auction.stake(getBNEth('200000'), { from: bob });
      await this.auction.stake(getBNEth('200000'), { from: alice });
      await this.auction.stake(getBNEth('100000'), { from: alice });
    });

    it('stake positive', async () => {
      expect(await this.auction.getDailyTotalStakedUnic(await this.auction.getLastMintTime())).to.be.bignumber.equal(getBNEth('500000'));
      expect(await this.auction.getStakedUnic(await this.auction.getLastMintTime(), { from: alice })).to.be.bignumber.equal(getBNEth('300000'));
      expect(await this.auction.getStakedUnic(await this.auction.getLastMintTime(), { from: bob })).to.be.bignumber.equal(getBNEth('200000'));
      expect(await this.unic.balanceOf(alice)).to.be.bignumber.equal(getBNEth('200000'));
      expect(await this.unic.balanceOf(bob)).to.be.bignumber.equal(getBNEth('1800000'));
      // 5% of staked unic
      expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(getBNEth('25000'));
    });

    it('stake negative', async () => {
      await expectRevert(this.auction.stake(0, { from: alice }), 'Invalid stake amount');
    });

    it('unstake positive', async () => {
      expect(await web3.eth.getBalance(this.auction.address)).to.be.bignumber.equal(getBNEth('5'));
      await this.auction.unStake(await this.auction.getLastMintTime(), { from: alice });
      expect(await web3.eth.getBalance(this.auction.address)).to.be.bignumber.equal(getBNEth('2.15'));
      expect(await this.auction.getStakedUnic(await this.auction.getLastMintTime(), { from: alice })).to.be.bignumber.equal(getBNEth('0'));
      await this.auction.unStake(await this.auction.getLastMintTime(), { from: bob });
      expect(await web3.eth.getBalance(this.auction.address)).to.be.bignumber.equal(getBNEth('0.25'));
      expect(await this.auction.getStakedUnic(await this.auction.getLastMintTime(), { from: bob })).to.be.bignumber.equal(getBNEth('0'));
    });

    it('unstake negative', async () => {
      await expectRevert(this.auction.unStake(await this.auction.getLastMintTime(), { from: owner }), 'Nothing to unstake');
      await this.auction.unStake(await this.auction.getLastMintTime(), { from: alice });
      await expectRevert(this.auction.unStake(await this.auction.getLastMintTime(), { from: alice }), 'Nothing to unstake');
    });

    // it('unstake positive remove not last item', async () => {
    //   await expectRevert(this.auction.getNumOfStakes({ from: alice }), 'No stakes');
    //   await this.auction.stake(getBNEth('200000'), 10, { from: alice });
    //   await this.auction.stake(getBNEth('300000'), 20, { from: alice });
    //   expect(await this.auction.getNumOfStakes({ from: alice })).to.be.bignumber.equal(new BN(2));
    //   await this.auction.participate({ from: owner, value: getBNEth('5')});
    //   expect((await this.auction.getStakeInfo(0, { from: alice }))[0]).to.be.bignumber.equal(getBNEth('200000'));
    //   expect((await this.auction.getStakeInfo(1, { from: alice }))[0]).to.be.bignumber.equal(getBNEth('300000'));
    //   await this.auction.unlockTokens({ from: owner });
    //   await this.auction.unStake(0, { from: alice });
    //   expect(await this.auction.getNumOfStakes({ from: alice })).to.be.bignumber.equal(new BN(1));
    //   expect((await this.auction.getStakeInfo(0, { from: alice }))[0]).to.be.bignumber.equal(getBNEth('300000'));
    // })

    // it('unstake remove all stakes and staker', async () => {
    //   await expectRevert(this.auction.getNumOfStakes({ from: bob }), 'No stakes');
    //   await expectRevert(this.auction.getNumOfStakes({ from: alice }), 'No stakes');
    //   await this.auction.stake(getBNEth('300000'), 20, { from: bob });
    //   await this.auction.stake(getBNEth('200000'), 10, { from: alice });
    //   await this.auction.stake(getBNEth('200000'), 10, { from: alice });
    //   expect(await this.auction.getNumOfStakes({ from: bob })).to.be.bignumber.equal(new BN(1));
    //   expect(await this.auction.getNumOfStakes({ from: alice } )).to.be.bignumber.equal(new BN(2));
    //   expect(await this.auction.getNumOfActiveStakers()).to.be.bignumber.equal(new BN(2));
    //   await expectRevert(this.auction.unlockTokens({ from: owner }), 'No participants');
    //   await this.auction.participate({ from: owner, value: getBNEth('5')});
    //   await this.auction.unlockTokens({ from: owner });
    //   expect(await this.auction.getNumOfStakes({ from: bob })).to.be.bignumber.equal(new BN(1));
    //   expect((await this.auction.getStakeInfo(0, { from: alice }))[0]).to.be.bignumber.equal(getBNEth('200000'));
    //   await this.auction.unStake(0, { from: bob });
    //   await expectRevert(this.auction.getNumOfStakes({ from: bob }), 'No stakes');
    //   expect(await this.auction.getNumOfActiveStakers()).to.be.bignumber.equal(new BN(1));
    //   await this.auction.unStake(1, { from: alice });
    //   await this.auction.unStake(0, { from: alice });
    //   await expectRevert(this.auction.getNumOfStakes({ from: alice }), 'No stakes');
    //   expect(await this.auction.getNumOfActiveStakers({ from: alice })).to.be.bignumber.equal(new BN(0));
    // })

    // it('unstake negative', async () => {
    //   await this.auction.stake(getBNEth('200000'), 10, { from: alice });
    //   await this.auction.participate({ from: owner, value: getBNEth('5')});
    //   expect(await this.auction.getNumOfStakes({ from: alice })).to.be.bignumber.equal(new BN(1));
    //   expect((await this.auction.getStakeInfo(0, { from: alice }))[0]).to.be.bignumber.equal(getBNEth('200000'));
    //   await this.auction.unlockTokens({ from: owner });
    //   await this.auction.unStake(0, { from: alice });
    //   await expectRevert(this.auction.getNumOfStakes({ from: alice }), 'No stakes');
    // })
  });
});

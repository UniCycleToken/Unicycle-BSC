const { BN, ether, expectRevert } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const UNICToken = artifacts.require('UNICToken');
const Auction = artifacts.require('FakeAuction');

contract('AUCTION test', async ([owner, alice, bob]) => {
  const startTime = Math.floor(Date.now() / 1000) - 86400 * 20;

  beforeEach(async () => {
    this.unic = await UNICToken.new({ from: owner });
    this.auction = await Auction.new(this.unic.address, startTime, { from: owner });
    await this.unic.setAuction(this.auction.address, { from: owner });
    expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('0'));
  });

  describe('check particpate and unlock after n day pause', async () => {
    it('N days', async () => {
      // 1 and 2 days pause
      await this.auction.participate(startTime + 86400 * 2, { from: alice, value: ether('1') });
      expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), { from: alice })).to.be.bignumber.equal(ether('1'));
      expect(await this.auction.getMintTimesLength()).to.be.bignumber.equal(new BN('2'));
      await this.auction.participate(startTime + 86400 * 3, { from: bob, value: ether('2') });
      expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), { from: bob })).to.be.bignumber.equal(ether('2'));
      expect(await this.auction.getMintTimesLength()).to.be.bignumber.equal(new BN('3'));
      expect(await this.auction.getTotalParticipateAmount({ from: alice })).to.be.bignumber.equal(ether('1'));
      expect(await this.auction.getTotalParticipateAmount({ from: bob })).to.be.bignumber.equal(ether('2'));
      // 3 and 4 days pause
      await this.auction.participate(startTime + 86400 * 4, { from: alice, value: ether('1') });
      expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), { from: alice })).to.be.bignumber.equal(ether('1'));
      expect(await this.auction.getMintTimesLength()).to.be.bignumber.equal(new BN('4'));
      await this.auction.participate(startTime + 86400 * 5, { from: bob, value: ether('2') });
      expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), { from: bob })).to.be.bignumber.equal(ether('2'));
      expect(await this.auction.getMintTimesLength()).to.be.bignumber.equal(new BN('5'));
      expect(await this.auction.getTotalParticipateAmount({ from: alice })).to.be.bignumber.equal(ether('2'));
      expect(await this.auction.getTotalParticipateAmount({ from: bob })).to.be.bignumber.equal(ether('4'));
      // 5 days pause
      await this.auction.participate(startTime + 86400 * 6, { from: alice, value: ether('1') });
      expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), { from: alice })).to.be.bignumber.equal(ether('1'));
      expect(await this.auction.getMintTimesLength()).to.be.bignumber.equal(new BN('6'));
      await this.auction.participate(startTime + 86400 * 6, { from: bob, value: ether('4') });
      expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), { from: bob })).to.be.bignumber.equal(ether('4'));
      expect(await this.auction.getMintTimesLength()).to.be.bignumber.equal(new BN('6'));
      expect(await this.auction.getTotalParticipateAmount({ from: alice })).to.be.bignumber.equal(ether('3'));
      expect(await this.auction.getTotalParticipateAmount({ from: bob })).to.be.bignumber.equal(ether('8'));
      // a lot of tokens, cause no one unlocked yet
      expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('12500000'));
      // now unlock them one by one
      await this.auction.unlockTokens(startTime + 86400 * 2, { from: alice });
      // alice was the only one participating that day she took all unics for the day
      expect(await this.unic.balanceOf(alice)).to.be.bignumber.equal(ether('2500000'));
      await this.auction.unlockTokens(startTime + 86400 * 3, { from: bob });
      // bob was the only one participating that day he took all unics for the day
      expect(await this.unic.balanceOf(bob)).to.be.bignumber.equal(ether('2500000'));
      // the balance of auction was subbed accordingly
      expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('7500000'));
      // unlock the tokens from the last day when bob and alice participate together
      await this.auction.unlockTokens(startTime + 86400 * 6, { from: alice });
      await this.auction.unlockTokens(startTime + 86400 * 6, { from: bob });
      expect(await this.unic.balanceOf(alice)).to.be.bignumber.equal(ether('3000000'));
      expect(await this.unic.balanceOf(bob)).to.be.bignumber.equal(ether('4500000'));
      expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('5000000'));
    });
  });

  describe('check stake bonus for n days', async () => {
    beforeEach(async () => {
      this.unic = await UNICToken.new({ from: owner });
      this.auction = await Auction.new(this.unic.address, startTime, { from: owner });
      await this.unic.setAuction(this.auction.address, { from: owner });
      expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('0'));
      await this.auction.participate(startTime + 86400, { from: owner, value: ether('1') });
      await this.auction.participate(startTime + 86400, { from: alice, value: ether('4') });
      await this.auction.unlockTokens(startTime + 86400, { from: owner });
      await this.auction.unlockTokens(startTime + 86400, { from: alice });
      expect(await this.unic.balanceOf(owner)).to.be.bignumber.equal(ether('500000'));
      expect(await this.unic.balanceOf(alice)).to.be.bignumber.equal(ether('2000000'));
      await this.unic.approve(this.auction.address, ether('500000'), { from: owner });
      await this.unic.approve(this.auction.address, ether('2000000'), { from: alice });
    });
    it('N days', async () => {
      await this.auction.stake(ether('500000'), startTime + 86400 * 2, { from: owner });
      await this.auction.stake(ether('2000000'), startTime + 86400 * 2, { from: alice });
      // 5% of what they staked left for LP stakers
      expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('125000'));
      // participate for 10 days
      for (let i = 3; i <= 12; i += 1) {
        // eslint-disable-next-line no-await-in-loop
        await this.auction.participate(startTime + 86400 * i, { from: bob, value: ether('5') });
      }
      expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('25125000'));
      expect(await web3.eth.getBalance(this.auction.address)).to.be.bignumber.equal(ether('55'));
      expect(await this.auction.getStakedUnic(startTime + 86400 * 2, { from: owner })).to.be.bignumber.equal(ether('500000'));
      await this.auction.unStake(startTime + 86400 * 2, startTime + 86400 * 20, { from: owner });
      // unstaked 20% of eth staked for 10 days => 10eth - 5%
      expect(await web3.eth.getBalance(this.auction.address)).to.be.bignumber.equal(ether('45.5'));
      await this.auction.unStake(startTime + 86400 * 2, startTime + 86400 * 20, { from: alice });
      // unstaked 20% of eth staked for 10 days => 40eth - 5%
      expect(await web3.eth.getBalance(this.auction.address)).to.be.bignumber.equal(ether('7.5'));
    });
  });
});

const {
  expectRevert, ether, constants, time,
} = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const UNICToken = artifacts.require('UNICToken');
const Auction = artifacts.require('Auction');
contract('Integration test', async ([owner, alice, bob]) => {

  beforeEach(async () => {
    const startTime = await time.latest();
    this.unic = await UNICToken.new({ from: owner });
    this.auction = await Auction.new(this.unic.address, startTime, owner, { from: owner });
    await this.unic.setAuction(this.auction.address, { from: owner });
  });
  it('auction constructor should fail', async () => {
    const startTime = await time.latest();
    await expectRevert(Auction.new(constants.ZERO_ADDRESS, startTime, owner, { from: owner }), 'ZERO ADDRESS');
  });

  describe('check participate/unlock', async () => {
    beforeEach(async () => {
      await time.increase(time.duration.days(1));
      expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('0'));
      await this.auction.participate({ from: alice, value: ether('1') });
      await this.auction.participate({ from: bob, value: ether('4') });
      expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('2500000'));
    });

    it('check team address', async () => {
      expect((await this.auction.getTeamInfo({ from: owner }))[1]).to.equal(owner);
    });

    it('participate positive', async () => {
      expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), alice, { from: alice })).to.be.bignumber.equal(ether('1'));
      expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), bob, { from: bob })).to.be.bignumber.equal(ether('4'));
    });

    it('participate negative', async () => {
      await expectRevert(this.auction.participate({ from: alice, value: ether('0') }), 'Insufficient participation');
    });

    it('unlock positive', async () => {
      await time.increase(time.duration.days(1));
      await this.auction.unlockTokens(await this.auction.getLastMintTime(), alice, { from: alice });
      await this.auction.unlockTokens(await this.auction.getLastMintTime(), bob, { from: bob });
      expect(await this.unic.balanceOf(alice)).to.be.bignumber.equal(ether('500000'));
      expect(await this.unic.balanceOf(bob)).to.be.bignumber.equal(ether('2000000'));
    });

    it('unlock negative', async () => {
      await expectRevert(this.auction.unlockTokens(await this.auction.getLastMintTime(), owner, { from: owner }), 'Nothing to unlock');
    });
  });

  describe('stake tests', async () => {
    beforeEach(async () => {
      expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('0'));
      await time.increase(time.duration.days(1));
      await this.auction.participate({ from: alice, value: ether('1') });
      await this.auction.participate({ from: bob, value: ether('4') });
      await time.increase(time.duration.days(1));
      await this.auction.unlockTokens(await this.auction.getLastMintTime(), alice, { from: alice });
      await this.auction.unlockTokens(await this.auction.getLastMintTime(), bob, { from: bob });
      expect(await this.unic.balanceOf(alice)).to.be.bignumber.equal(ether('500000'));
      expect(await this.unic.balanceOf(bob)).to.be.bignumber.equal(ether('2000000'));
      await this.unic.approve(this.auction.address, ether('500000'), { from: alice });
      await this.unic.approve(this.auction.address, ether('500000'), { from: bob });
      // stake tokens
      await this.auction.stake(ether('200000'), { from: bob });
      await this.auction.stake(ether('200000'), { from: alice });
      await this.auction.stake(ether('100000'), { from: alice });
    });

    it('stake positive', async () => {
      const startTime = (await this.auction.getLastMintTime()).toNumber();
      expect(await this.auction.getStakedUnic(startTime + 86400, alice, { from: alice })).to.be.bignumber.equal(ether('300000'));
      expect(await this.auction.getStakedUnic(startTime + 86400, bob, { from: bob })).to.be.bignumber.equal(ether('200000'));
      expect(await this.unic.balanceOf(alice)).to.be.bignumber.equal(ether('200000'));
      expect(await this.unic.balanceOf(bob)).to.be.bignumber.equal(ether('1800000'));
      // 5% of staked unic
      expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('25000'));
    });

    it('stake negative', async () => {
      await expectRevert(this.auction.stake(0, { from: alice }), 'Invalid stake amount');
    });

    it('unstake', async () => {
      const startTime = (await this.auction.getLastMintTime()).toNumber();
      expect(await web3.eth.getBalance(this.auction.address)).to.be.bignumber.equal(ether('5'));
      await expectRevert(this.auction.unstake(startTime + 86400, alice, { from: alice }), 'At least 1 day must pass');
      // a day has not passed
      expect(await web3.eth.getBalance(this.auction.address)).to.be.bignumber.equal(ether('5'));
      expect(await this.auction.getStakedUnic(startTime + 86400, alice, { from: alice })).to.be.bignumber.equal(ether('300000'));
      await expectRevert(this.auction.unstake(startTime + 86400, bob, { from: bob }), 'At least 1 day must pass');
      // a day has not passed
      expect(await web3.eth.getBalance(this.auction.address)).to.be.bignumber.equal(ether('5'));
      expect(await this.auction.getStakedUnic(startTime + 86400, bob, { from: bob })).to.be.bignumber.equal(ether('200000'));
    });
  });
});

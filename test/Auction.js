const {
  expectRevert, ether, constants, time,
} = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const { cycle } = require('./Utils');

const CYCLEToken = artifacts.require('CYCLEToken');
const Auction = artifacts.require('Auction');
const WETH = artifacts.require('WETH9');
const UniswapV2Pair = artifacts.require('UniswapV2Pair');
const UniswapV2Router02 = artifacts.require('UniswapV2Router02');
const UniswapV2Factory = artifacts.require('UniswapV2Factory');

contract('AUCTION test', async ([owner, alice, bob]) => {
  beforeEach(async () => {
    const startTime = await time.latest();
    this.cycle = await CYCLEToken.new({ from: owner });
    this.weth = await WETH.new({ from: owner });
    this.factory = await UniswapV2Factory.new(owner, { from: owner });
    this.team = web3.eth.accounts.create();
    this.router = await UniswapV2Router02.new(this.factory.address, this.weth.address, { from: owner });
    this.auction = await Auction.new(this.cycle.address, this.router.address, startTime, this.team.address, { from: owner });
    await this.cycle.setAuction(this.auction.address, { from: owner });
    const pair = await this.factory.getPair(this.weth.address, this.cycle.address);
    await this.cycle.setCYCLEWETHAddress(pair, { from: owner });
  });

  it('auction constructor should fail', async () => {
    const startTime = await time.latest();
    await expectRevert(Auction.new(constants.ZERO_ADDRESS, constants.ZERO_ADDRESS, startTime, this.team.address, { from: owner }), 'ZERO ADDRESS');
  });

  it('checking getCycleAddress', async () => {
    expect(await this.auction.getCycleAddress()).to.equal(this.cycle.address);
  });

  it('checking getCycleAddress', async () => {
    expect(await this.auction.getCycleAddress()).to.equal(this.cycle.address);
  });

  it('participate first day wallet cap negative', async () => {
    await expectRevert(this.auction.participate({ from: alice, value: ether('16') }), 'First day wallet cap reached');
  });

  describe('check participate/unlock', async () => {
    beforeEach(async () => {
      await time.increase(time.duration.days(1));
      expect(await this.cycle.balanceOf(this.auction.address)).to.be.bignumber.equal(cycle('0'));
      await this.auction.participate({ from: alice, value: ether('1') });
      await this.auction.participate({ from: bob, value: ether('4') });
      expect(await this.cycle.balanceOf(this.auction.address)).to.be.bignumber.equal(cycle('100000'));
    });

    it('check team address', async () => {
      expect((await this.auction.getTeamInfo({ from: owner }))[1]).to.equal(this.team.address);
    });

    // it('takeTeamEthShare should fail', async () => {
    //   await expectRevert(this.auction.takeTeamETHShare({ from: owner }), 'Wait one day to take your share');
    // });

    it('participate positive', async () => {
      expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), alice, { from: alice })).to.be.bignumber.equal(ether('1'));
      expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), bob, { from: bob })).to.be.bignumber.equal(ether('4'));
    });

    it('participate negative', async () => {
      await expectRevert(this.auction.participate({ from: alice, value: ether('0') }), 'Insufficient participation');
    });

    it('should fail unlocking the same day as partcipating', async () => {
      await expectRevert(this.auction.takeShare(await this.auction.getLastMintTime(), alice, { from: alice }), 'At least 1 day must pass');
    });

    it('unlock positive', async () => {
      await time.increase(time.duration.days(1));
      await this.auction.takeShare(await this.auction.getLastMintTime(), alice, { from: alice });
      await this.auction.takeShare(await this.auction.getLastMintTime(), bob, { from: bob });
      expect(await this.cycle.balanceOf(alice)).to.be.bignumber.equal(cycle('20000'));
      expect(await this.cycle.balanceOf(bob)).to.be.bignumber.equal(cycle('80000'));
    });

    it('unlock negative', async () => {
      await expectRevert(this.auction.takeShare(await this.auction.getLastMintTime(), owner, { from: owner }), 'Nothing to unlock');
    });

    it('add liquidity positive', async () => {
      await time.increase(time.duration.days(1));

      await this.auction.participate({ from: alice, value: ether('1') });
      expect(await this.cycle.balanceOf(this.team.address)).to.be.bignumber.equal(cycle('50000'));
      expect(await web3.eth.getBalance(this.team.address)).to.be.bignumber.equal(ether('2.5'));

      const pairAddress = await this.factory.getPair(this.weth.address, this.cycle.address);
      expect(pairAddress).not.to.equal(constants.ZERO_ADDRESS);
      expect(await this.cycle.balanceOf(pairAddress)).to.be.bignumber.equal(cycle('50000'));
      expect(await this.weth.balanceOf(pairAddress)).to.be.bignumber.equal(ether('2.5'));

      const pair = await UniswapV2Pair.at(pairAddress);
      expect(await pair.balanceOf(this.team.address)).to.be.bignumber.not.equal(ether('0'));
    });
  });

  describe('stake tests', async () => {
    beforeEach(async () => {
      expect(await this.cycle.balanceOf(this.auction.address)).to.be.bignumber.equal(cycle('0'));
      await time.increase(time.duration.days(1));
      await this.auction.participate({ from: alice, value: ether('1') });
      await this.auction.participate({ from: bob, value: ether('4') });
      await time.increase(time.duration.days(1));
      await this.auction.takeShare(await this.auction.getLastMintTime(), alice, { from: alice });
      await this.auction.takeShare(await this.auction.getLastMintTime(), bob, { from: bob });
      expect(await this.cycle.balanceOf(alice)).to.be.bignumber.equal(cycle('20000'));
      expect(await this.cycle.balanceOf(bob)).to.be.bignumber.equal(cycle('80000'));
      await this.cycle.approve(this.auction.address, cycle('20000'), { from: alice });
      await this.cycle.approve(this.auction.address, cycle('20000'), { from: bob });
      // stake tokens
      await this.auction.stake(cycle('8000'), { from: bob });
      await this.auction.stake(cycle('8000'), { from: alice });
      await this.auction.stake(cycle('4000'), { from: alice });
    });

    it('stake positive', async () => {
      const startTime = (await this.auction.getLastMintTime()).toNumber();
      expect(await this.auction.getStakedCycle(startTime + 86400, alice, { from: alice })).to.be.bignumber.equal(cycle('12000'));
      expect(await this.auction.getStakedCycle(startTime + 86400, bob, { from: bob })).to.be.bignumber.equal(cycle('8000'));
      expect(await this.cycle.balanceOf(alice)).to.be.bignumber.equal(cycle('8000'));
      expect(await this.cycle.balanceOf(bob)).to.be.bignumber.equal(cycle('72000'));
      // 5% of staked cycle
      expect(await this.cycle.balanceOf(this.auction.address)).to.be.bignumber.equal(cycle('1000'));
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
      expect(await this.auction.getStakedCycle(startTime + 86400, alice, { from: alice })).to.be.bignumber.equal(cycle('12000'));
      await expectRevert(this.auction.unstake(startTime + 86400, bob, { from: bob }), 'At least 1 day must pass');
      // a day has not passed
      expect(await web3.eth.getBalance(this.auction.address)).to.be.bignumber.equal(ether('5'));
      expect(await this.auction.getStakedCycle(startTime + 86400, bob, { from: bob })).to.be.bignumber.equal(cycle('8000'));
    });
  });
});

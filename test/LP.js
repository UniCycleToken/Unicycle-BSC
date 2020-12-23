const {
  expectRevert, ether, time, BN,
} = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const UNICToken = artifacts.require('UNICToken');
const Auction = artifacts.require('Auction');
const WETH = artifacts.require('WETH9');
const UniswapV2Pair = artifacts.require('UniswapV2Pair');
const UniswapV2Router02 = artifacts.require('UniswapV2Router02');
const UniswapV2Factory = artifacts.require('UniswapV2Factory');

contract('LP related test', async ([owner, alice, bob]) => {
  beforeEach(async () => {
    const auctionStartTime = await time.latest();
    this.unic = await UNICToken.new({ from: owner });
    this.weth = await WETH.new({ from: owner });
    this.factory = await UniswapV2Factory.new(owner, { from: owner });
    await this.factory.createPair(this.weth.address, this.unic.address);
    this.auction = await Auction.new(this.unic.address, auctionStartTime, owner, { from: owner });
    await this.unic.setAuction(this.auction.address, { from: owner });
    this.router = await UniswapV2Router02.new(this.factory.address, this.weth.address, { from: owner });
  });

  it('check that remove liquidity is blocked', async () => {
    const startTime = (await this.auction.getLastMintTime()).toNumber();
    await time.increase(time.duration.days(2));
    // prepare LPStake for owner
    await this.auction.participate({ from: owner, value: ether('1') });
    await this.weth.deposit({ from: owner, value: ether('30') });
    await this.unic.approve(this.router.address, ether('30'), { from: owner });
    await this.weth.approve(this.router.address, ether('30'), { from: owner });
    // prepare LPStake for alice
    await this.auction.participate({ from: alice, value: ether('1') });
    await this.weth.deposit({ from: alice, value: ether('30') });
    await this.unic.approve(this.router.address, ether('30'), { from: alice });
    await this.weth.approve(this.router.address, ether('30'), { from: alice });
    await time.increase(time.duration.days(1));
    await this.auction.unlockTokens(startTime + 86400 * 2, { from: owner });
    await this.auction.unlockTokens(startTime + 86400 * 2, { from: alice });
    expect(await this.unic.balanceOf(owner)).to.be.bignumber.equal(ether('1250000'));
    expect(await this.unic.balanceOf(alice)).to.be.bignumber.equal(ether('1250000'));
    const blockTime = await time.latest();
    await this.router.addLiquidity(this.weth.address, this.unic.address, ether('10'), ether('10'), 0, 0, owner, blockTime + 30, { from: owner });
    const lpTokenAddress = await this.factory.getPair(this.weth.address, this.unic.address);
    this.lpToken = await UniswapV2Pair.at(lpTokenAddress);
    await this.lpToken.approve(this.router.address, ether('10'), { from: owner });
    await this.router.removeLiquidity(this.weth.address, this.unic.address, ether('1'), 0, 0, owner, blockTime + 60, { from: owner });
    expect(await this.unic.isBlacklisted(lpTokenAddress)).to.equal(false);
    await this.unic.addToBlacklist(lpTokenAddress);
    expect(await this.unic.isBlacklisted(lpTokenAddress)).to.equal(true);
    await this.router.addLiquidity(this.weth.address, this.unic.address, ether('10'), ether('10'), 0, 0, owner, blockTime + 90, { from: owner });
    await expectRevert(this.router.removeLiquidity(this.weth.address, this.unic.address, ether('1'), 0, 0, owner, blockTime + 120, { from: owner }), 'UniswapV2: TRANSFER_FAILED');
    await this.unic.rempoveFromBlacklist(lpTokenAddress);
    await this.router.removeLiquidity(this.weth.address, this.unic.address, ether('1'), 0, 0, owner, blockTime + 150, { from: owner });
  });

  it('check LPStake reward payout', async () => {
    const startTime = (await this.auction.getLastMintTime()).toNumber();
    await time.increase(time.duration.days(2));
    // prepare LPStake for owner
    await this.auction.participate({ from: owner, value: ether('1') });
    await this.weth.deposit({ from: owner, value: ether('30') });
    await this.unic.approve(this.router.address, ether('30'), { from: owner });
    await this.weth.approve(this.router.address, ether('30'), { from: owner });
    // prepare LPStake for alice
    await this.auction.participate({ from: alice, value: ether('1') });
    await this.weth.deposit({ from: alice, value: ether('30') });
    await this.unic.approve(this.router.address, ether('30'), { from: alice });
    await this.weth.approve(this.router.address, ether('30'), { from: alice });
    // prepare LPStake for Bob
    await this.auction.participate({ from: bob, value: ether('3') });
    await this.weth.deposit({ from: bob, value: ether('30') });
    await this.unic.approve(this.router.address, ether('30'), { from: bob });
    await this.weth.approve(this.router.address, ether('30'), { from: bob });
    await time.increase(time.duration.days(1));
    await this.auction.unlockTokens(startTime + 86400 * 2, { from: owner });
    await this.auction.unlockTokens(startTime + 86400 * 2, { from: alice });
    await this.auction.unlockTokens(startTime + 86400 * 2, { from: bob });
    expect(await this.unic.balanceOf(owner)).to.be.bignumber.equal(ether('500000'));
    expect(await this.unic.balanceOf(alice)).to.be.bignumber.equal(ether('500000'));
    expect(await this.unic.balanceOf(bob)).to.be.bignumber.equal(ether('1500000'));

    const blockTime = await time.latest();
    await this.router.addLiquidity(this.weth.address, this.unic.address, ether('10'), ether('10'), 0, 0, owner, blockTime + 30, { from: owner });
    await this.router.addLiquidity(this.weth.address, this.unic.address, ether('10'), ether('10'), 0, 0, alice, blockTime + 30, { from: alice });
    await this.router.addLiquidity(this.weth.address, this.unic.address, ether('10'), ether('10'), 0, 0, bob, blockTime + 30, { from: bob });
    const lpTokenAddress = await this.factory.getPair(this.weth.address, this.unic.address);
    this.lpToken = await UniswapV2Pair.at(lpTokenAddress);
    await this.lpToken.approve(this.auction.address, ether('10'), { from: owner });
    await this.lpToken.approve(this.auction.address, ether('10'), { from: alice });
    await this.lpToken.approve(this.auction.address, ether('10'), { from: bob });
    await this.unic.addToBlacklist(lpTokenAddress);
    expect(await this.auction.canUnlockLPReward(startTime + 86400 * 3, { from: owner })).to.be.bignumber.equal(ether('0'));
    expect(await this.auction.canUnlockLPReward(startTime + 86400 * 3, { from: alice })).to.be.bignumber.equal(ether('0'));
    await expectRevert(this.auction.stakeLP(lpTokenAddress, ether('0'), { from: owner }), 'Invalid stake amount');
    await expectRevert(this.auction.stakeLP(alice, ether('0'), { from: owner }), 'Token is not supported');
    await this.auction.stakeLP(lpTokenAddress, ether('0.5'), { from: owner });
    expect(await this.auction.getAccumulativeLP()).to.be.bignumber.equal(ether('0.5'));
    expect(await this.auction.getStakedLP(startTime + 86400 * 3, owner, { from: owner })).to.be.bignumber.equal(ether('0.5'));
    await this.auction.stakeLP(lpTokenAddress, ether('0.5'), { from: owner });
    expect(await this.auction.getAccumulativeLP()).to.be.bignumber.equal(ether('1'));
    expect(await this.auction.getStakedLP(startTime + 86400 * 3, owner, { from: owner })).to.be.bignumber.equal(ether('1'));
    await this.auction.stakeLP(lpTokenAddress, ether('4'), { from: alice });
    expect(await this.auction.getAccumulativeLP()).to.be.bignumber.equal(ether('5'));
    expect(await this.auction.getStakedLP(startTime + 86400 * 3, alice, { from: alice })).to.be.bignumber.equal(ether('4'));
    expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('0'));
    for (let i = 0; i < 10; i += 1) {
      // eslint-disable-next-line no-await-in-loop
      await this.auction.participate({ from: bob, value: ether('5') });
      // eslint-disable-next-line no-await-in-loop
      await time.increase(time.duration.days(1));
    }
    expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('25000000'));
    expect(await this.unic.balanceOf(owner)).to.be.bignumber.equal(ether('499990'));
    expect(await this.auction.canUnlockLPReward(startTime + 86400 * 3, { from: owner })).to.be.bignumber.equal(ether('250000'));
    expect(await this.auction.getLastLpUnlockTime(startTime + 86400 * 3, owner, { from: owner })).to.be.bignumber.equal(new BN(startTime + 86400 * 3));
    await expectRevert(this.auction.unlockLPReward(startTime + 86400 * 2, { from: owner }), 'Nothing to unlock');
    await this.auction.unlockLPReward(startTime + 86400 * 3, { from: owner });
    expect(await this.auction.getLastLpUnlockTime(startTime + 86400 * 3,owner, { from: owner })).to.be.bignumber.equal(new BN(startTime + 86400 * 13));
    expect(await this.auction.canUnlockLPReward(startTime + 86400 * 3, { from: owner })).to.be.bignumber.equal(ether('0'));
    // + 2 500 000 * 10 / 20 = 1 250 000, owners share is 20% => 250 000
    expect(await this.unic.balanceOf(owner)).to.be.bignumber.equal(ether('749990'));
    expect(await this.unic.balanceOf(alice)).to.be.bignumber.equal(ether('499990'));
    expect(await this.auction.canUnlockLPReward(startTime + 86400 * 3, { from: alice })).to.be.bignumber.equal(ether('1000000'));
    
    await this.auction.unlockLPReward(startTime + 86400 * 3, { from: alice });
    expect(await this.auction.canUnlockLPReward(startTime + 86400 * 3, { from: alice })).to.be.bignumber.equal(ether('0'));
    // + 2 500 000 * 10 / 20 = 1 250 000, alice share is 80% => 1 000 000
    expect(await this.unic.balanceOf(alice)).to.be.bignumber.equal(ether('1499990'));

    // add another LP staker in the middle of new participation cycle
    for (let i = 0; i < 5; i += 1) {
      // eslint-disable-next-line no-await-in-loop
      await this.auction.participate({ from: alice, value: ether('5') });
      // eslint-disable-next-line no-await-in-loop
      await time.increase(time.duration.days(1));
    }
    expect(await this.auction.canUnlockLPReward(startTime + 86400 * 3, { from: owner })).to.be.bignumber.equal(ether('125000'));
    expect(await this.auction.canUnlockLPReward(startTime + 86400 * 3, { from: alice })).to.be.bignumber.equal(ether('500000'));
    await this.auction.stakeLP(lpTokenAddress, ether('5'), { from: bob });
    for (let i = 0; i < 5; i += 1) {
      // eslint-disable-next-line no-await-in-loop
      await this.auction.participate({ from: owner, value: ether('5') });
      // eslint-disable-next-line no-await-in-loop
      await time.increase(time.duration.days(1));
    }
    expect(await this.auction.canUnlockLPReward(startTime + 86400 * 3, { from: owner })).to.be.bignumber.equal(ether('187500'));
    expect(await this.auction.canUnlockLPReward(startTime + 86400 * 3, { from: alice })).to.be.bignumber.equal(ether('750000'));
    expect(await this.auction.canUnlockLPReward(startTime + 86400 * 18, { from: bob })).to.be.bignumber.equal(ether('312500'));
    await this.auction.unlockLPReward(startTime + 86400 * 3, { from: owner });
    expect(await this.auction.getLastLpUnlockTime(startTime + 86400 * 3, owner, { from: owner })).to.be.bignumber.equal(new BN(startTime + 86400 * 23));
    await this.auction.unlockLPReward(startTime + 86400 * 3, { from: alice });
    await this.auction.unlockLPReward(startTime + 86400 * 18, { from: bob });
    expect(await this.auction.canUnlockLPReward(startTime + 86400 * 3, { from: owner })).to.be.bignumber.equal(ether('0'));
    expect(await this.auction.canUnlockLPReward(startTime + 86400 * 3, { from: alice })).to.be.bignumber.equal(ether('0'));
    expect(await this.auction.canUnlockLPReward(startTime + 86400 * 18, { from: bob })).to.be.bignumber.equal(ether('0'));
  });
  // takes 6-10mins
  // it('check LP stake for 1000 days breakpoint', async () => {
  //   const startTime = (await this.auction.getLastMintTime()).toNumber();
  //   await time.increase(time.duration.days(2));
  //   // prepare LPStake for alice
  //   await this.auction.participate({ from: alice, value: ether('1') });
  //   await this.weth.deposit({ from: alice, value: ether('10') });
  //   await this.unic.approve(this.router.address, ether('10'), { from: alice });
  //   await this.weth.approve(this.router.address, ether('10'), { from: alice });
  //   await time.increase(time.duration.days(1));
  //   await this.auction.unlockTokens(startTime + 86400 * 2, { from: alice });
  //   expect(await this.unic.balanceOf(alice)).to.be.bignumber.equal(ether('2500000'));

  //   const blockTime = await time.latest();
  //   await this.router.addLiquidity(this.weth.address, this.unic.address, ether('10'), ether('10'), 0, 0, alice, blockTime + 30, { from: alice });
  //   const lpTokenAddress = await this.factory.getPair(this.weth.address, this.unic.address);
  //   this.lpToken = await UniswapV2Pair.at(lpTokenAddress);
  //   await this.lpToken.approve(this.auction.address, ether('10'), { from: alice });
  //   await this.unic.addToBlacklist(lpTokenAddress);
  //   await this.auction.stakeLP(lpTokenAddress, ether('1'), { from: alice });
  //   expect(await this.auction.getAccumulativeLP()).to.be.bignumber.equal(ether('1'));
  //   expect(await this.auction.getStakedLP(startTime + 86400 * 3, alice, { from: alice })).to.be.bignumber.equal(ether('1'));
  //   expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('0'));
  //   for (let i = 0; i < 1100; i += 1) {
  //     // eslint-disable-next-line no-await-in-loop
  //     await this.auction.participate({ from: bob, value: ether('0.01') });
  //     // eslint-disable-next-line no-await-in-loop
  //     await time.increase(time.duration.days(1));
  //   }
  //   expect(await this.auction.canUnlockLPReward(startTime + 86400 * 3, { from: alice })).to.be.bignumber.equal(ether('137500000'));
  //   expect(await this.auction.getLastLpUnlockTime(startTime + 86400 * 3, alice, { from: alice })).to.be.bignumber.equal(new BN(startTime + 86400 * 3));
  //   await this.auction.unlockLPReward(startTime + 86400 * 3, { from: alice });
  //   expect(await this.auction.getLastLpUnlockTime(startTime + 86400 * 3, alice, { from: alice })).to.be.bignumber.equal(new BN(startTime + 86400 * 1103));
  // });
});

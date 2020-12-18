const { BN, ether, time } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const UNICToken = artifacts.require('UNICToken');
const Auction = artifacts.require('Auction');

contract('AUCTION test', async ([owner, alice, bob]) => {
  beforeEach(async () => {
    const startTime = await time.latest();
    this.unic = await UNICToken.new({ from: owner });
    this.auction = await Auction.new(this.unic.address, startTime, { from: owner });
    await this.unic.setAuction(this.auction.address, { from: owner });
    expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('0'));
  });

  it('check participate and unlock after n day pause', async () => {
    const startTime = (await this.auction.getLastMintTime()).toNumber();
    await time.increase(time.duration.days(2)); // startTime + 86400 * 2,
    await this.auction.participate({ from: alice, value: ether('1') });
    expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), { from: alice })).to.be.bignumber.equal(ether('1'));
    expect(await this.auction.getMintTimesLength()).to.be.bignumber.equal(new BN('2'));
    await time.increase(time.duration.days(1)); // startTime + 86400 * 3,
    await this.auction.participate({ from: bob, value: ether('2') });
    expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), { from: bob })).to.be.bignumber.equal(ether('2'));
    expect(await this.auction.getMintTimesLength()).to.be.bignumber.equal(new BN('3'));
    expect(await this.auction.getTotalParticipateAmount({ from: alice })).to.be.bignumber.equal(ether('1'));
    expect(await this.auction.getTotalParticipateAmount({ from: bob })).to.be.bignumber.equal(ether('2'));
    // 3 and 4 days pause
    await time.increase(time.duration.days(1)); // startTime + 86400 * 4,
    await this.auction.participate({ from: alice, value: ether('1') });
    expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), { from: alice })).to.be.bignumber.equal(ether('1'));
    expect(await this.auction.getMintTimesLength()).to.be.bignumber.equal(new BN('4'));
    await time.increase(time.duration.days(1)); // startTime + 86400 * 5,
    await this.auction.participate({ from: bob, value: ether('2') });
    expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), { from: bob })).to.be.bignumber.equal(ether('2'));
    expect(await this.auction.getMintTimesLength()).to.be.bignumber.equal(new BN('5'));
    expect(await this.auction.getTotalParticipateAmount({ from: alice })).to.be.bignumber.equal(ether('2'));
    expect(await this.auction.getTotalParticipateAmount({ from: bob })).to.be.bignumber.equal(ether('4'));
    // 5 days pause
    await time.increase(time.duration.days(1)); // startTime + 86400 * 6,
    await this.auction.participate({ from: alice, value: ether('1') });
    expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), { from: alice })).to.be.bignumber.equal(ether('1'));
    expect(await this.auction.getMintTimesLength()).to.be.bignumber.equal(new BN('6'));
    await this.auction.participate({ from: bob, value: ether('4') });
    expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), { from: bob })).to.be.bignumber.equal(ether('4'));
    expect(await this.auction.getMintTimesLength()).to.be.bignumber.equal(new BN('6'));
    expect(await this.auction.getTotalParticipateAmount({ from: alice })).to.be.bignumber.equal(ether('3'));
    expect(await this.auction.getTotalParticipateAmount({ from: bob })).to.be.bignumber.equal(ether('8'));
    // a lot of tokens, cause no one unlocked yet
    expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('12500000'));
    // await time.advanceBlock();
    // now unlock them one by one
    // console.log(await this.auction.canUnlockTokens(startTime + 86400 * 2, { from: alice }));
    await time.increase(time.duration.days(4)); // startTime + 86400 * 10,
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

  it('Check stake and unstake for n days', async () => {
    const startTime = (await this.auction.getLastMintTime()).toNumber();
    await time.increase(time.duration.days(2)); // startTime + 86400,
    await this.auction.participate({ from: owner, value: ether('1') });
    await this.auction.participate({ from: alice, value: ether('1') });
    await this.auction.participate({ from: bob, value: ether('3') });
    await time.increase(time.duration.days(1)); // startTime + 86400,
    await this.auction.unlockTokens(startTime + 86400 * 2, { from: owner });
    await this.auction.unlockTokens(startTime + 86400 * 2, { from: alice });
    await this.auction.unlockTokens(startTime + 86400 * 2, { from: bob });
    expect(await this.unic.balanceOf(owner)).to.be.bignumber.equal(ether('500000'));
    expect(await this.unic.balanceOf(alice)).to.be.bignumber.equal(ether('500000'));
    expect(await this.unic.balanceOf(bob)).to.be.bignumber.equal(ether('1500000'));
    await this.unic.approve(this.auction.address, ether('500000'), { from: owner });
    await this.unic.approve(this.auction.address, ether('500000'), { from: alice });
    await this.unic.approve(this.auction.address, ether('1500000'), { from: bob });
    expect(await this.auction.getAccumulative()).to.be.bignumber.equal(ether('0'));
    await this.auction.stake(ether('500000'), { from: owner });
    expect(await this.auction.getAccumulative()).to.be.bignumber.equal(ether('500000'));
    await this.auction.stake(ether('500000'), { from: alice });
    expect(await this.auction.getAccumulative()).to.be.bignumber.equal(ether('1000000'));
    expect(await this.auction.getStakedUnic(startTime + 86400 * 3, { from: owner })).to.be.bignumber.equal(ether('500000'));
    expect(await this.auction.getStakedUnic(startTime + 86400 * 3, { from: alice })).to.be.bignumber.equal(ether('500000'));
    expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('50000'));
    for (let i = 0; i < 5; i += 1) {
      // eslint-disable-next-line no-await-in-loop
      await this.auction.participate({ from: owner, value: ether('5') });
      // eslint-disable-next-line no-await-in-loop
      await time.increase(time.duration.days(1));
    }
    expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('12550000'));
    expect(await web3.eth.getBalance(this.auction.address)).to.be.bignumber.equal(ether('30'));
    expect(await this.auction.canUnStake(startTime + 86400 * 3, { from: owner })).to.be.bignumber.equal(ether('11.875'));
    expect(await this.auction.canUnStake(startTime + 86400 * 3, { from: alice })).to.be.bignumber.equal(ether('11.875'));
    await this.auction.stake(ether('1500000'), { from: bob });
    expect(await this.auction.getAccumulative()).to.be.bignumber.equal(ether('2500000'));
    for (let i = 0; i < 5; i += 1) {
      // eslint-disable-next-line no-await-in-loop
      await this.auction.participate({ from: owner, value: ether('5') });
      // eslint-disable-next-line no-await-in-loop
      await time.increase(time.duration.days(1));
    }
    expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('25125000'));
    expect(await web3.eth.getBalance(this.auction.address)).to.be.bignumber.equal(ether('55'));
    expect(await this.auction.getStakedUnic(startTime + 86400 * 3, { from: owner })).to.be.bignumber.equal(ether('500000'));
    expect(await this.auction.canUnStake(startTime + 86400 * 3, { from: owner })).to.be.bignumber.equal(ether('16.625'));
    expect(await this.auction.canUnStake(startTime + 86400 * 3, { from: alice })).to.be.bignumber.equal(ether('16.625'));
    expect(await this.auction.canUnStake(startTime + 86400 * 8, { from: bob })).to.be.bignumber.equal(ether('14.25'));
  });

  // describe('check stake bonus for n days when another staker is added', async () => {
  //   beforeEach(async () => {
  //     this.unic = await UNICToken.new({ from: owner });
  //     this.auction = await Auction.new(this.unic.address, startTime, { from: owner });
  //     await this.unic.setAuction(this.auction.address, { from: owner });
  //     expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('0'));
  //     await this.auction.participate(startTime + 86400, { from: owner, value: ether('1') });
  //     await this.auction.participate(startTime + 86400, { from: alice, value: ether('4') });
  //     await this.auction.unlockTokens(startTime + 86400, startTime + 86400 * 2, { from: owner });
  //     await this.auction.unlockTokens(startTime + 86400, startTime + 86400 * 2, { from: alice });
  //     expect(await this.unic.balanceOf(owner)).to.be.bignumber.equal(ether('500000'));
  //     expect(await this.unic.balanceOf(alice)).to.be.bignumber.equal(ether('2000000'));
  //     await this.unic.approve(this.auction.address, ether('500000'), { from: owner });
  //     await this.unic.approve(this.auction.address, ether('2000000'), { from: alice });
  //   });
  //   it('N days', async () => {

  //   });
  // });
  // describe('check stake bonus for n days when another staker is added', async () => {
  //   beforeEach(async () => {
  //     this.unic = await UNICToken.new({ from: owner });
  //     this.auction = await Auction.new(this.unic.address, startTime, { from: owner });
  //     await this.unic.setAuction(this.auction.address, { from: owner });
  //     expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('0'));
  //     await this.auction.participate(startTime + 86400, { from: owner, value: ether('1') });
  //     await this.auction.participate(startTime + 86400, { from: alice, value: ether('1') });
  //     await this.auction.participate(startTime + 86400, { from: bob, value: ether('3') });
  //     await this.auction.unlockTokens(startTime + 86400, startTime + 86400 * 2, { from: owner });
  //     await this.auction.unlockTokens(startTime + 86400, startTime + 86400 * 2, { from: alice });
  //     await this.auction.unlockTokens(startTime + 86400, startTime + 86400 * 2, { from: bob });
  //     expect(await this.unic.balanceOf(owner)).to.be.bignumber.equal(ether('500000'));
  //     expect(await this.unic.balanceOf(alice)).to.be.bignumber.equal(ether('500000'));
  //     expect(await this.unic.balanceOf(bob)).to.be.bignumber.equal(ether('1500000'));
  //     await this.unic.approve(this.auction.address, ether('500000'), { from: owner });
  //     await this.unic.approve(this.auction.address, ether('500000'), { from: alice });
  //     await this.unic.approve(this.auction.address, ether('1500000'), { from: bob });
  //   });
  //   it('N days', async () => {
  //     await this.auction.stake(ether('500000'), startTime + 86400 * 2, { from: owner });
  //     await this.auction.stake(ether('500000'), startTime + 86400 * 2, { from: alice });
  //     expect(await this.auction.getStakedUnic(startTime + 86400 * 2, { from: owner })).to.be.bignumber.equal(ether('500000'));
  //     expect(await this.auction.getStakedUnic(startTime + 86400 * 2, { from: alice })).to.be.bignumber.equal(ether('500000'));
  //     // 5% of staked 1 000 000
  //     expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('50000'));
  //     for (let i = 3; i < 8; i += 1) {
  //       // eslint-disable-next-line no-await-in-loop
  //       await this.auction.participate(startTime + 86400 * i, { from: owner, value: ether('5') });
  //     }
  //     expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('12550000'));
  //     expect(await web3.eth.getBalance(this.auction.address)).to.be.bignumber.equal(ether('30'));
  //     // half of what participated ETH - 5%
  //     expect(await this.auction.canUnStake(startTime + 86400 * 2, { from: owner })).to.be.bignumber.equal(ether('11.875'));
  //     expect(await this.auction.canUnStake(startTime + 86400 * 2, { from: alice })).to.be.bignumber.equal(ether('11.875'));
  //     await this.auction.stake(ether('1500000'), startTime + 86400 * 9, { from: bob });
  //     for (let i = 10; i < 15; i += 1) {
  //       // eslint-disable-next-line no-await-in-loop
  //       await this.auction.participate(startTime + 86400 * i, { from: owner, value: ether('5') });
  //     }
  //     expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('25125000'));
  //     expect(await web3.eth.getBalance(this.auction.address)).to.be.bignumber.equal(ether('55'));
  //     expect(await this.auction.canUnStake(startTime + 86400 * 2, { from: owner })).to.be.bignumber.equal(ether('16.625'));
  //     expect(await this.auction.canUnStake(startTime + 86400 * 2, { from: alice })).to.be.bignumber.equal(ether('16.625'));
  //     // expect(await this.auction.canUnStake(startTime + 86400 * 9, { from: bob })).to.be.bignumber.equal(ether('14.25'));
  //   });
});

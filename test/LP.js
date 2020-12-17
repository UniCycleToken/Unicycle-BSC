// const {
//   BN,
//   expectRevert,
//   ether,
// } = require('@openzeppelin/test-helpers');
// const { expect } = require('chai');

// const UNICToken = artifacts.require('UNICToken');
// const Auction = artifacts.require('Auction');
// const WETH = artifacts.require('WETH9');
// const UniswapV2Pair = artifacts.require('UniswapV2Pair');
// const UniswapV2Router02 = artifacts.require('UniswapV2Router02');
// const UniswapV2Factory = artifacts.require('UniswapV2Factory');

// contract('LP related test', async ([owner, alice]) => {

//   beforeEach(async () => {
//     this.unic = await UNICToken.new({ from: owner });
//     this.auction = await Auction.new(this.unic.address, { from: owner });
//     this.weth = await WETH.new({ from: owner });
//     this.factory = await UniswapV2Factory.new(owner, { from: owner });
//     this.router = await UniswapV2Router02.new(this.factory.address, this.weth.address, { from: owner });

//     await this.unic.setAuction(this.auction.address, { from: owner });
//     await this.unic.mint(ether('2500000'), { from: owner });
//     await this.unic.addBurner(this.auction.address, { from: owner });
//     // prepare LPStake for owner
//     await this.auction.participate({ from: owner, value: ether('1') });
//     await this.weth.deposit({ from: owner, value: ether('30') });
//     await this.unic.approve(this.router.address, ether('30'), { from: owner });
//     await this.weth.approve(this.router.address, ether('30'), { from: owner });
//     // prepare LPStake for alice
//     await this.auction.participate({ from: alice, value: ether('1') });
//     await this.weth.deposit({ from: alice, value: ether('30') });
//     await this.unic.approve(this.router.address, ether('30'), { from: alice });
//     await this.weth.approve(this.router.address, ether('30'), { from: alice });

//     await this.auction.unlockTokens({ from: owner });
//   });

//   it('check that remove liquidity is blocked', async () => {
//     const blocktime = (await web3.eth.getBlock()).timestamp;
//     await this.router.addLiquidity(this.weth.address, this.unic.address, ether('10'), ether('10'), 0, 0, owner, blocktime + 30, { from: owner });
//     const lpTokenAddress = await this.factory.getPair(this.weth.address, this.unic.address);
//     this.lpToken = await UniswapV2Pair.at(lpTokenAddress);
//     await this.lpToken.approve(this.router.address, ether('10'), { from: owner });
//     await this.router.removeLiquidity(this.weth.address, this.unic.address, ether('1'), 0, 0, owner, blocktime + 60, { from: owner });
//     await this.unic.addToBlacklist(lpTokenAddress);
//     await this.router.addLiquidity(this.weth.address, this.unic.address, ether('10'), ether('10'), 0, 0, owner, blocktime + 90, { from: owner });
//     await expectRevert(this.router.removeLiquidity(this.weth.address, this.unic.address, ether('1'), 0, 0, owner, blocktime + 120, { from: owner }), 'UniswapV2: TRANSFER_FAILED');
//     await this.unic.rempoveFromBlacklist(lpTokenAddress);
//     await this.router.removeLiquidity(this.weth.address, this.unic.address, ether('1'), 0, 0, owner, blocktime + 60, { from: owner });
//   });

//   describe('check lpStake', async () => {
//     beforeEach(async () => {
//       const blocktime = (await web3.eth.getBlock()).timestamp;
//       await this.router.addLiquidity(this.weth.address, this.unic.address, ether('10'), ether('10'), 0, 0, owner, blocktime + 30, { from: owner });
//       await this.router.addLiquidity(this.weth.address, this.unic.address, ether('10'), ether('10'), 0, 0, owner, blocktime + 30, { from: alice });
//       const lpTokenAddress = await this.factory.getPair(this.weth.address, this.unic.address);
//       this.lpToken = await UniswapV2Pair.at(lpTokenAddress);
//     });
//     it('positive', async () => {
//       await this.lpToken.approve(this.router.address, ether('10'), { from: owner });
//       await this.lpToken.approve(this.router.address, ether('10'), { from: alice });
//       await this.unic.addToBlacklist(lpTokenAddress);
//       await this.auction.LPStake(lpTokenAddress, ether('1'), { from: owner });
//       await this.auction.LPStake(lpTokenAddress, ether('2'), { from: alice });

//       expect((await this.auction.getLPStakeInfo({ from: owner }))[0]).to.equal(owner);
//       expect((await this.auction.getLPStakeInfo({ from: alice }))[0]).to.equal(alice);
//       expect((await this.auction.getLPStakeInfo({ from: owner }))[1]).to.be.bignumber.equal(ether('1'));
//       expect((await this.auction.getLPStakeInfo({ from: alice }))[1]).to.be.bignumber.equal(ether('2'));
//       expect(await this.auction.getNumOfLPStakers()).to.be.bignumber.equal(new BN(2));
//       expect(await this.auction._totalStakedLP({ from: owner })).to.be.bignumber.equal(ether('3'));

//       await this.auction.LPStake(lpTokenAddress, ether('2'), { from: owner });
//       await this.auction.LPStake(lpTokenAddress, ether('3'), { from: alice });

//       expect((await this.auction.getLPStakeInfo({ from: owner }))[1]).to.be.bignumber.equal(ether('3'));
//       expect((await this.auction.getLPStakeInfo({ from: alice }))[1]).to.be.bignumber.equal(ether('5'));
//       expect(await this.auction._totalStakedLP({ from: owner })).to.be.bignumber.equal(ether('8'));

//       await this.unic.approve(this.auction.address, ether('500000'), { from: owner });

//       expect(await this.unic.balanceOf(owner, { from: owner })).to.be.bignumber.equal(ether('1249990'));
//       expect(await this.unic.balanceOf(alice, { from: alice })).to.be.bignumber.equal(ether('1249990'));

//       await this.auction.stake(ether('10'), 10, { from: owner });
//       // 5% of staked 10 * (10 ** 18) were proportionally distibuted between LP stakers
//       expect(await this.unic.balanceOf(owner, { from: owner })).to.be.bignumber.equal(ether('1249980.1875'));
//       expect(await this.unic.balanceOf(alice, { from: alice })).to.be.bignumber.equal(ether('1249990.3125'));
//     });
//   });
// });

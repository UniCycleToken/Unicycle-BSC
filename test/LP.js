фв/* eslint-disable */
const {
  BN,
  expectRevert,
} = require('openzeppelin-test-helpers');
const { expect } = require('chai');
const { getBNEth } = require('../utils/getBN');

const UNICToken = artifacts.require('UNICToken');
const Auction = artifacts.require('Auction');
const WETH = artifacts.require('WETH9');
const UniswapV2Pair = artifacts.require('UniswapV2Pair');
const UniswapV2Router02 = artifacts.require('UniswapV2Router02');
const UniswapV2Factory = artifacts.require('UniswapV2Factory');

contract('LP related test', async ([owner, alice, bob]) => {
	const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

	beforeEach(async () => {
		this.unic = await UNICToken.new({ from: owner });
		this.auction = await Auction.new(this.unic.address, { from: owner });
		this.weth = await WETH.new({ from: owner });
		this.factory = await UniswapV2Factory.new(owner, { from: owner });
		this.router = await UniswapV2Router02.new(this.factory.address, this.weth.address, { from: owner });

		await this.unic.setAuction(this.auction.address, { from: owner });
		await this.unic.mint(getBNEth('2500000'), { from: owner });
		await this.unic.addBurner(this.auction.address, { from: owner });
		// prepare LPStake for owner
		await this.auction.participate({ from: owner, value: getBNEth('1')});
		await this.weth.deposit({ from: owner, value: getBNEth('30') },);
		await this.unic.approve(this.router.address, getBNEth('30'), { from: owner });
		await this.weth.approve(this.router.address, getBNEth('30'), { from: owner });
		// prepare LPStake for alice
		await this.auction.participate({ from: alice, value: getBNEth('1')});
		await this.weth.deposit({ from: alice, value: getBNEth('30') });
		await this.unic.approve(this.router.address, getBNEth('30'), { from: alice });
		await this.weth.approve(this.router.address, getBNEth('30'), { from: alice });

		await this.auction.unlockTokens({ from: owner });
	});

	
	it('heck that remove liquidity is blocked', async () => {
		const blocktime = (await web3.eth.getBlock()).timestamp;
		await this.router.addLiquidity(this.weth.address, this.unic.address, getBNEth('10'), getBNEth('10'), 0, 0, owner, blocktime + 30, {from: owner});
		const lpTokenAddress = await this.factory.getPair(this.weth.address, this.unic.address);
		this.lpToken = await UniswapV2Pair.at(lpTokenAddress);
		await this.lpToken.approve(this.router.address, getBNEth('10'), { from: owner });
		await this.router.removeLiquidity(this.weth.address, this.unic.address, getBNEth('1'), 0, 0, owner, blocktime + 60, {from: owner});
		await this.unic.addToBlacklist(lpTokenAddress);
		await this.router.addLiquidity(this.weth.address, this.unic.address, getBNEth('10'), getBNEth('10'), 0, 0, owner, blocktime + 90, {from: owner});
		await expectRevert(this.router.removeLiquidity(this.weth.address, this.unic.address, getBNEth('1'), 0, 0, owner, blocktime + 120, {from: owner}), 'UniswapV2: TRANSFER_FAILED');
		await this.unic.rempoveFromBlacklist(lpTokenAddress);
		await this.router.removeLiquidity(this.weth.address, this.unic.address, getBNEth('1'), 0, 0, owner, blocktime + 60, {from: owner});
	})

	describe('check lpStake', async () => {
		beforeEach(async () => {
			const blocktime = (await web3.eth.getBlock()).timestamp;
			await this.router.addLiquidity(this.weth.address, this.unic.address, getBNEth('10'), getBNEth('10'), 0, 0, owner, blocktime + 30, {from: owner});
			await this.router.addLiquidity(this.weth.address, this.unic.address, getBNEth('10'), getBNEth('10'), 0, 0, owner, blocktime + 30, {from: alice});
		})
		it('positive', async () => {
			const lpTokenAddress = await this.factory.getPair(this.weth.address, this.unic.address);
			this.lpToken = await UniswapV2Pair.at(lpTokenAddress);
			await this.lpToken.approve(this.router.address, getBNEth('10'), { from: owner });
			await this.lpToken.approve(this.router.address, getBNEth('10'), { from: alice });
			await this.unic.addToBlacklist(lpTokenAddress);
			await this.auction.LPStake(lpTokenAddress, getBNEth('1'), { from: owner });
			await this.auction.LPStake(lpTokenAddress, getBNEth('2'), { from: alice });
			expect(await this.auction.getLPStakeInfo({ from: owner })).to.be.bignumber.equal(getBNEth('1'));
			expect(await this.auction.getLPStakeInfo({ from: alice })).to.be.bignumber.equal(getBNEth('2'));
			await this.auction.LPStake(lpTokenAddress, getBNEth('2'), { from: owner });
			await this.auction.LPStake(lpTokenAddress, getBNEth('3'), { from: alice });
			expect(await this.auction.getLPStakeInfo({ from: owner })).to.be.bignumber.equal(getBNEth('3'));
			expect(await this.auction.getLPStakeInfo({ from: alice })).to.be.bignumber.equal(getBNEth('5'));
		})
		
	})
});

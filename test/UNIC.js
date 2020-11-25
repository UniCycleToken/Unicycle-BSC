/* eslint-disable */
const {
  BN,
  expectRevert,
} = require('openzeppelin-test-helpers');
const { expect } = require('chai');
const { getBNEth } = require('../utils/getBN');

const UNICToken = artifacts.require('UNICToken');
const Auction = artifacts.require('Auction');

contract('UNIC test', async ([owner, burner, holder]) => {
  const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

  beforeEach(async () => {
    this.unic = await UNICToken.new({ from: owner });
    this.auction = await Auction.new(this.unic.address, { from: owner });
    await this.unic.setAuction(this.auction.address);
  });

  it('checking the unic token parameters', async () => {
    expect(await this.unic.name.call()).to.equal('UNICToken');
    expect(await this.unic.symbol.call()).to.equal('UNIC');
    expect(await this.unic.decimals.call()).to.be.bignumber.equal(new BN('18'));
    expect(await this.unic.totalSupply.call()).to.be.bignumber.equal(new BN('0'));
  });

  describe('check burn', async () => {
    beforeEach(async () => {
      await this.unic.mint(getBNEth('1'), { from: owner });
    })

    it('checking isBurnAllowed function', async () => {
      expect(await this.unic.isBurnAllowed(owner, { from: owner })).to.equal(true);
      expect(await this.unic.isBurnAllowed(holder, { from: owner })).to.equal(false);
    });

    it('addBurner positive tests', async () => {
      expect(await this.unic.isBurnAllowed(burner), { from: owner }).to.equal(false);
      await this.unic.addBurner(burner, { from: owner });
      expect(await this.unic.isBurnAllowed(burner, { from: owner })).to.equal(true);
      await expectRevert(this.unic.addBurner(burner, { from: owner }), 'Already burner');
    });

    it('addBurner negative tests', async () => {
      await expectRevert(this.unic.addBurner(burner, { from: holder }), 'Ownable: caller is not the owner');
      await expectRevert(this.unic.addBurner(ZERO_ADDRESS, { from: owner }), 'Cant add zero address');
    });

    it('removeBurner positive tests', async () => {
      await this.unic.addBurner(burner, { from: owner });
      expect(await this.unic.isBurnAllowed(burner, { from: burner })).to.equal(true);
      await this.unic.removeBurner(burner, { from: owner });
      expect(await this.unic.isBurnAllowed(burner, { from: burner })).to.equal(false);
    });

    it('removeBurner negative tests', async () => {
      await expectRevert(this.unic.removeBurner(holder, { from: owner }), 'Isnt burner');
    });

    it('burn positive tests', async () => {
      await this.unic.burn(getBNEth('0.5'), { from: owner });
      expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(getBNEth('0.5'));
    })

    it('burn negative tests', async () => {
      await expectRevert(this.unic.burn(getBNEth('0.5'), { from: holder }), 'Caller is not burner');
      await expectRevert.unspecified(this.unic.burn(getBNEth('1.1'), { from: owner }));
    })
  })

  describe('check mint', async () => {
    
    it('mint positive tests', async () => {
      await this.unic.mint(getBNEth('1'), { from: owner });
      expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(getBNEth('1'));
    })

    // it('mint negative tests', async () => {
    //   await expectRevert.unspecified(this.unic.mint(getBNEth('1'), { from: burner }));
    //   await expectRevert(this.unic.mint(getBNEth('2500001')), 'No mint over 2500000 tokens');
    //   await this.unic.mint(getBNEth('2500000'), { from: owner });
    //   expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(getBNEth('2500000'));
    //   await expectRevert(this.unic.mint(getBNEth('1')), 'No mint over 2500000 tokens');
    // })
  })
  describe('check blacklist', async () => {
    it('blacklist positive tests', async () => {
      await this.unic.addToBlacklist(holder, { from: owner });
      expect(await this.unic.blacklistedAddresses(holder)).to.equal(true);
      await this.unic.rempoveFromBlacklist(holder, { from: owner });
      expect(await this.unic.blacklistedAddresses(holder)).to.equal(false);
    })

    it('blacklist negative tests', async () => {
      await this.unic.addToBlacklist(holder, { from: owner });
      await expectRevert(this.unic.addToBlacklist(holder, { from: owner }), 'In black list');
      await this.unic.rempoveFromBlacklist(holder, { from: owner });
      await expectRevert(this.unic.rempoveFromBlacklist(holder, { from: owner }), 'Not blacklisted');
      await expectRevert.unspecified(this.unic.rempoveFromBlacklist(burner, { from: holder }));
    })
  })

  describe('check transfer', async () => {
    // it('transfer positive tests', async () => {
    //   await this.unic.addToBlacklist(holder, { from: owner });
    // })

    // it('transfer negative tests', async () => {
    //   await this.unic.addToBlacklist(holder, { from: owner });
    //   await expectRevert(this.unic.transfer(owner, getBNEth('0.5'), {from: holder }), 'Blacklisted.');
    // })
  })
});

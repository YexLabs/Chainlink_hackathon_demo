const {
    time,
    loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");
  
describe("YexILOExample", function () {

    async function deployYexILO() {
    
        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount] = await ethers.getSigners();
    
        const YexILOExample = await ethers.getContractFactory("YexILOExample");
        const yexILOExample = await YexILOExample.deploy(100);
    
        return { yexILOExample, owner, otherAccount };
    }

    describe("Deployment", function () {
        it("Deploy", async function () {
            const { yexILOExample, owner, otherAccount } = await loadFixture(deployYexILO);
        });
    });
    describe("Deposit", function () {
        it("deposit", async function () {
            const { yexILOExample, owner, otherAccount } = await loadFixture(deployYexILO);
            // erc20 pair
            const ERC20WithFaucet = await ethers.getContractFactory("contracts/core/YexILOExample.sol:ERC20WithFaucet");
            const ERC20Mintable = await ethers.getContractFactory("ERC20Mintable");
            // token
            const tokenA = ERC20WithFaucet.attach(await yexILOExample.tokenA());
            const tokenB = ERC20Mintable.attach(await yexILOExample.tokenB());


            await tokenA.connect(otherAccount).faucet();
            await tokenA.connect(owner).faucet();
            await tokenA.connect(otherAccount).approve(yexILOExample.address, await tokenA.balanceOf(otherAccount.address));
            await tokenA.connect(owner).approve(yexILOExample.address, await tokenA.balanceOf(owner.address));

            await tokenB.connect(owner).approve(yexILOExample.address, await tokenB.balanceOf(owner.address));


            // deposit tokenA
            await yexILOExample.connect(otherAccount).deposit(500000000000000000n, 0);
            // deposit tokenB
            await yexILOExample.connect(owner).deposit(0, await tokenB.balanceOf(owner.address));

            await expect(yexILOExample.connect(owner).performUpkeep("0x")).to.be.revertedWith("fund raising time is not over or no deposit");
            await time.increase(100);

            await yexILOExample.connect(owner).performUpkeep("0x");

            console.log(await yexILOExample.balanceOf(owner.address));
            console.log(await yexILOExample.balanceOf(otherAccount.address));
            
        

        });
    });
    describe("Liquidity", function () {
        it("liquidity", async function () {
            const { yexILOExample, owner, otherAccount } = await loadFixture(deployYexILO);
            // erc20 pair
            const ERC20WithFaucet = await ethers.getContractFactory("contracts/core/YexILOExample.sol:ERC20WithFaucet");
            const ERC20Mintable = await ethers.getContractFactory("ERC20Mintable");
            // token
            const tokenA = ERC20WithFaucet.attach(await yexILOExample.tokenA());
            const tokenB = ERC20Mintable.attach(await yexILOExample.tokenB());


            await tokenA.faucet();
            await tokenA.approve(yexILOExample.address, await tokenA.balanceOf(owner.address));
            await tokenB.approve(yexILOExample.address, await tokenB.balanceOf(owner.address));

            const owner_tokenA = await tokenA.balanceOf(owner.address);
            const owner_tokenB = await tokenB.balanceOf(owner.address);

            // add liquidity 
            // await yexILOExample.addLiquidity(10000000000n, 10000000000n);

            // approve
            // const lp_balance = await yexILOExample.balanceOf(owner.address);
            // console.log(lp_balance);
            // await yexILOExample.approve(yexILOExample.address, lp_balance);
            // await yexILOExample.removeLiquidity(lp_balance/100000, 0);
  
        

        });
    });
  });
  
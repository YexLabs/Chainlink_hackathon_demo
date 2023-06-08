# **Chainlink_hackathon_demo**

This repo is for Chainlink hackathon demo of YexLab.

<p align="center">
  <a href="#">demo video</a> •
  <a href="#">slides</a> •
  <a href="https://yexlab.vercel.app/demo1_swap">demo page</a> 
</p>

## **Problems**

There are two known problems with AMM: 

### **Slippage**

When the liquidity depth is not enough, the slippage is large. 

If there are two transactions in different directions but with the same amount at the same time, an AMM with a constant K as the formula will return to the initial position, and the price of the first transaction among the two traders will be unfair.

This makes sense because he pushed up the price and took the slippage, and the latter one sold at a higher price.

In fact, if these two people swap tokens directly with each other, there is no slippage. In fact if you have a large amount of tokens to sell, say 1000 ETH, you definitely don't want to be incurring a huge slippage. If you use the idea of **Batch Auction**, you should be willing to wait for a while for anyone who wants to buy ETH from you.

### **Sandwich Attack**

Arbitrage bot places their own two transactions around a victim’s transaction with the intention of manipulating the price and profiting from the user. That is called a sandwich attack.

The first transaction will push up the price, and let the second transaction(which is victim's) be executed at a higher price.  The attacker sell token in the third transaction and profit from it.

This is a very common MEV approach that actually caused by slippage of AMMs as well.

## **Solutions**

We call the solution as **Batch Swap**, including three parts: **Batch Auction**, **A2MM** and **Chainlink Automation**.


Star with a esay example: 

> In a time window, some people want to swap LINK for USDT and deposit LINK into the contract, while others want to swap USDT for LINK and deposit USDT into the contract. We assume that there are 50 LINK and 1000 USDT in the contract, and the market price at that time is 1 LINK worth 10 USDT, then 500 USDT will swap for LINK directly while the other 500 USDT will be swapped in AMM.

We gather some random transaction demands within a time window, and exchange the symmetrical part directly, while the insufficient part uses AMM to fill the swap.

### **Batch Auction**

We practiced **Batch Auction** to extend AMM. **Batch Auction** is commonly used in web2 exchanges to alleviate the problem of insufficient liquidity in commodities transactions. 

We use the same idea, use a window of time to gather a batch of swaps and implement a unified clearing price for them, making them independent of the ranking.

The defination in Crypto Wiki is as follows:

* Individual orders are grouped together into a batch and executed at the same time. 

* The same clearing price is assigned to all orders within one batch. 

* Trading in batch auctions helps guarantee fair price discovery and avoid MEV(Sandwich Attack).

The benefits of this are obvious, and direct exchange is always the most cost-effective method. This process is order-independent, that is, no value can be extracted by ranking a transaction to an earlier or later position.

### **A2MM**

But **Batch Auction** is not enough, if the demand is asymmetric, the excess demand will go to the AMM, where the attacker waits there. 

So we implemented an **A2MM** aggregator, that is, aggregated the liquidity of multiple AMMs, and only selected one with the best price when a swap execute. This means that an attacker would have to attack multiple AMMs simultaneously to affect this transaction.

![a2mm](https://raw.githubusercontent.com/yexlab/Chainlink_hackathon_demo/main/docs/images/A2MM.png)

As shown in the picture, the aggregator chooses AMM and does the swap in the same transaction, so when the attacker front-running the trader, the aggregator will choose another AMM with better price to avoid the attack.

### **Chainlink Automation**

Chainlink Automation is the infrastructure of batch swap:

* Create time windows and check that the swap volume and timestamp in a batch meet the requirements.
* Calculate the best price AMM then to do swap for tokens to balance demand.
* Automatic distribution tokens -- users do not need to wait for results and claim token, token will be automatically withdrawn to users' account.

Chainlink Automation allows us to automate the process: control the swap, choose a right time to match the balanced demand directly, and choose a best AMM to swap the excess demand.

Finally, Chainlink Automation can also automatically distribute tokens, letting users free from a claim. This minimizes the gas fee on the user side and achieves the best user experience by reducing the number of interactions.


## Technical details

This process is divided into two parts. First, a transaction initiated by a random user activates the contract and starts timing, waiting for the counterparty to enter for a period of time.

Chainlink Automation is the controller of the entire process. If there are enough counterparties, the waiting time will be shorter, otherwise, it will be longer, but there is always an upper limit.

When the time is up, Chainlink Automation will call the contract automatically to swap the symmetrical part, and to swap the remaining part by AMM. Selecting AMM and executing the swap is in the same transaction, so others cannot insert a transaction in it. And the contract always chooses the AMM with the best price.

Finally, Chainlink Automation will automatically distribute the tokens to the user, and the user does not need to claim them.

In our demo, the price is obtained by sorting multiple aggregated AMMs. If we have more time, we also hope to obtain a reasonable price through Chainlink Price Oracle.

## What's next for YexLab

We plan to implement **Batch Swap** in our DEX product [Splatter Protocol](https://www.splatterprotocol.xyz/).
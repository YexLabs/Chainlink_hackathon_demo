# Chainlink_hackathon_demo

This repo is for Chainlink hackathon demo of YexLab.

## Problems

There are two known problems with AMM: 

1. When the liquidity depth is not enough, the slippage is large;
2. Transaction ordering attack (also known as the sandwich attack);

We practiced Batch Auction, which is commonly used in web2 exchanges to alleviate the problem of insufficient liquidity in commodities transactions. We call it Batch Swap.

At the same time, Chainlink Automation allows us to automate this process: control the swap process and choose the right time to match the balanced demand directly, and choose the best AMM to swap the excess demand.

Finally, Chainlink Automation can also automatically distribute tokens, letting users free from a claim. This minimizes the gas fee on the user side and achieves the best user experience by reducing the number of interactions.

## Solutions

We gather some random transaction demands within a time window, and exchange the symmetrical part directly, while the insufficient part uses AMM to fill the swap.

To use a simple example: 

> In a time window, some people want to swap ETH for USDT and deposit ETH into the contract, while others want to swap USDT for ETH and deposit USDT into the contract. We assume that there are 1 ETH and 500 USDT in the contract, and the market price at that time is 1 ETH worth 1000 USDT, then 0.5 ETH will be swapped in AMM, and 0.5 ETH will be swapped directly.

The benefits of this are obvious, and direct exchange is always the most cost-effective method. This process is order-independent, that is, no value can be extracted by ranking a transaction to an earlier or later position.

But this is not enough, if the demand is asymmetric, the excess demand will go to the AMM, where the attacker waits there. 
So we used the A2MM method, that is, aggregated the liquidity of multiple AMMs, and only selected one with the best price when a swap execute. This means that an attacker would have to attack multiple AMMs simultaneously to affect this transaction.

## Technical details

This process is divided into two parts. First, a transaction initiated by a random user activates the contract and starts timing, waiting for the counterparty to enter for a period of time.

Chainlink Automation is the controller of the entire process. If there are enough counterparties, the waiting time will be shorter, otherwise, it will be longer, but there is always an upper limit.

When the time is up, Chainlink Automation will call the contract automatically to swap the symmetrical part, and to swap the remaining part by AMM. Selecting AMM and executing the swap is in the same transaction, so others cannot insert a transaction in it. And the contract always chooses the AMM with the best price.

Finally, Chainlink Automation will automatically distribute the tokens to the user, and the user does not need to claim them.

In our demo, the price is obtained by sorting multiple aggregated AMMs. If we have more time, we also hope to obtain a reasonable price through Chainlink Price Oracle.

## What's next for YexLab

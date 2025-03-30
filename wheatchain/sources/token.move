module wheatchain::token {
use sui::coin::{Self, Coin, TreasuryCap};
use sui::transfer;
use sui::tx_context::{Self, TxContext};
use std::option;

/// The whSUI token one-time witness
public struct WHSUI has drop {}

/// Initialize the whSUI token
#[allow(unused_variable)]
fun init(ctx: &mut TxContext) {
// Create a new currency with proper one-time witness pattern
let witness = WHSUI {};
let (treasury_cap, metadata) = coin::create_currency(
witness,
9, // 9 decimals
b"whSUI",
b"WheatChain SUI",
b"Staking reward token for WheatChain",
option::none(),
ctx
);

// Transfer the treasury cap and metadata to the sender
transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
transfer::public_transfer(metadata, tx_context::sender(ctx));
}

/// Mint whSUI (admin-only in production)
public entry fun mint(
treasury: &mut TreasuryCap<WHSUI>,
  amount: u64,
  recipient: address,
  ctx: &mut TxContext
  ) {
  let coin = coin::mint(treasury, amount, ctx);
  transfer::public_transfer(coin, recipient);
  }
  
  /// Burn whSUI to redeem SUI (used in staking)
  public entry fun burn(
  treasury: &mut TreasuryCap<WHSUI>,
    coin: Coin<WHSUI>
      ) {
      coin::burn(treasury, coin);
      }
      }
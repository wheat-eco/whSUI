module wheatchain::token {
use sui::coin::{Self, Coin, TreasuryCap, CoinMetadata};
use sui::transfer;
use sui::tx_context::{Self, TxContext};
use std::option;
use sui::package;

/// The whSUI token one-time witness
struct TOKEN has drop {}

/// The whSUI token type
public struct WHSUI has drop {}

/// Initialize the whSUI token
fun init(otw: TOKEN, ctx: &mut TxContext) {
let (treasury_cap, metadata) = coin::create_currency<WHSUI>(
  otw,
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
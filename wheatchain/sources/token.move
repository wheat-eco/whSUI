module wheatchain::token {
use std::option;
use sui::url::{Self, Url};
use sui::coin::{Self, Coin, TreasuryCap};
use sui::balance::{Self, Supply, Balance};
use sui::transfer;
use sui::tx_context::{Self, TxContext};
use sui::object::{Self, UID};
use sui::event;

// Track the current version of the module
const VERSION: u64 = 1;

/// The whSUI token one-time witness
public struct TOKEN has drop {}

/// The whSUI token type
public struct WHSUI has store, drop {}

/// Changeable metadata of whSUI token
public struct TokenMetadata has key, store {
id: UID,
version: u64,
total_supply: Supply<WHSUI>,
  }
  
  /// Initialize the whSUI token
  fun init(witness: TOKEN, ctx: &mut TxContext) {
  // Create coin with metadata
  let (treasury_cap, metadata) = coin::create_currency<WHSUI>(
    witness,
    9, // 9 decimals
    b"whSUI",
    b"WheatChain SUI",
    b"Staking reward token for WheatChain",
    option::some<Url>(url::new_unsafe_from_bytes(b"https://wheatchain.com/whsui-logo.png")),
      ctx
      );
      
      // Freeze the metadata so it can't be changed
      transfer::public_freeze_object(metadata);
      
      // Convert treasury cap to supply and store in our custom metadata
      let supply = coin::treasury_into_supply(treasury_cap);
      transfer::share_object(TokenMetadata {
      id: object::new(ctx),
      version: VERSION,
      total_supply: supply,
      });
      }
      
      /// Get total supply of whSUI tokens
      public fun get_total_supply(metadata: &TokenMetadata): &Supply<WHSUI> {
        &metadata.total_supply
        }
        
        /// Get total supply value of whSUI tokens
        public fun get_total_supply_value(metadata: &TokenMetadata): u64 {
        balance::supply_value(&metadata.total_supply)
        }
        
        /// Mint new whSUI tokens (admin function)
        public fun mint(
        metadata: &mut TokenMetadata,
        amount: u64,
        ctx: &mut TxContext
        ): Coin<WHSUI> {
          let minted_balance = balance::increase_supply(&mut metadata.total_supply, amount);
          coin::from_balance(minted_balance, ctx)
          }
          
          /// Burn whSUI tokens
          public fun burn(
          metadata: &mut TokenMetadata,
          coin: Coin<WHSUI>
            ): u64 {
            balance::decrease_supply(&mut metadata.total_supply, coin::into_balance(coin))
            }
            
            /// Entry function for minting
            public entry fun mint_entry(
            metadata: &mut TokenMetadata,
            amount: u64,
            recipient: address,
            ctx: &mut TxContext
            ) {
            let coin = mint(metadata, amount, ctx);
            transfer::public_transfer(coin, recipient);
            }
            
            /// Entry function for burning
            public entry fun burn_entry(
            metadata: &mut TokenMetadata,
            coin: Coin<WHSUI>
              ) {
              burn(metadata, coin);
              }
              
              #[test_only]
              /// Wrapper of module initializer for testing
              public fun test_init(ctx: &mut TxContext) {
              init(TOKEN {}, ctx)
              }
              }
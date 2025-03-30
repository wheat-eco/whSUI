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

/// The whSUI token one-time witness (must have same name as module)
public struct WHSUI has drop {}

/// Changeable metadata of whSUI token
public struct TokenMetadata has key, store {
id: UID,
version: u64,
total_supply: Supply<WHSUI>,
  }
  
  /// Initialize the whSUI token
  fun init(witness: WHSUI, ctx: &mut TxContext) {
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
      
      // Freeze the metadata and share supply information
      transfer::public_freeze_object(metadata);
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
        
        /// Internal mint function
        fun mint(
        metadata: &mut TokenMetadata,
        amount: u64,
        ctx: &mut TxContext
        ): Coin<WHSUI> {
          let minted_balance = balance::increase_supply(&mut metadata.total_supply, amount);
          coin::from_balance(minted_balance, ctx)
          }
          
          /// Internal burn function
          fun burn(
          metadata: &mut TokenMetadata,
          coin: Coin<WHSUI>
            ): u64 {
            balance::decrease_supply(&mut metadata.total_supply, coin::into_balance(coin))
            }
            
            /// Entry function for minting whSUI tokens
            public entry fun mint_tokens(
            metadata: &mut TokenMetadata,
            amount: u64,
            recipient: address,
            ctx: &mut TxContext
            ) {
            let coin = mint(metadata, amount, ctx);
            transfer::public_transfer(coin, recipient);
            }
            
            /// Entry function for burning whSUI tokens
            public entry fun burn_tokens(
            metadata: &mut TokenMetadata,
            coin: Coin<WHSUI>
              ) {
              burn(metadata, coin);
              }
              
              // ========== Testing Functions ========== //
              #[test_only]
              /// Wrapper of module initializer for testing
              public fun test_init(ctx: &mut TxContext) {
              init(WHSUI {}, ctx)
              }
              
              #[test_only]
              /// Test mint helper function
              public fun test_mint(
              metadata: &mut TokenMetadata,
              amount: u64,
              ctx: &mut TxContext
              ): Coin<WHSUI> {
                mint(metadata, amount, ctx)
                }
                
                #[test_only]
                /// Test burn helper function
                public fun test_burn(
                metadata: &mut TokenMetadata,
                coin: Coin<WHSUI>
                  ): u64 {
                  burn(metadata, coin)
                  }
                  }
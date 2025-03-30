/// Module: whsui.move
/// WheatChain Staked SUI Token Implementation
module wheatchain::whsui {
use std::option;
use sui::url::{Self, Url};
use sui::coin::{Self, Coin, TreasuryCap};
use sui::balance::{Self, Supply, Balance};
use sui::transfer;
use sui::tx_context::{Self, TxContext};
use sui::object::{Self, UID};
use sui::event;

/// Current module version
const VERSION: u64 = 1;

/// One-time witness MUST match module name (whsui)
public struct WHSUI has drop {}

/// Main token type
public struct WHSUI_Token has store, drop {}

/// Token metadata (shared object)
public struct WhSuiMetadata has key, store {
id: UID,
version: u64,
total_supply: Supply<WHSUI_Token>,
  }
  
  /// Initialize the WHSUI token
  fun init(witness: WHSUI, ctx: &mut TxContext) {
  let (treasury_cap, metadata) = coin::create_currency<WHSUI_Token>(
    witness,
    9, // 9 decimals
    b"whSUI", // Symbol
    b"WheatChain Staked SUI", // Name
    b"Liquid staking token for WheatChain ecosystem", // Description
    option::some<Url>(url::new_unsafe_from_bytes(b"https://wheatchain.com/whsui.png")),
      ctx
      );
      
      // Make metadata immutable
      transfer::public_freeze_object(metadata);
      
      // Convert treasury cap to supply and share metadata
      let supply = coin::treasury_into_supply(treasury_cap);
      transfer::share_object(WhSuiMetadata {
      id: object::new(ctx),
      version: VERSION,
      total_supply: supply,
      });
      }
      
      /// Mint new WHSUI tokens (internal)
      fun mint(
      metadata: &mut WhSuiMetadata,
      amount: u64,
      ctx: &mut TxContext
      ): Coin<WHSUI_Token> {
        let minted_balance = balance::increase_supply(&mut metadata.total_supply, amount);
        coin::from_balance(minted_balance, ctx)
        }
        
        /// Burn WHSUI tokens (internal)
        fun burn(
        metadata: &mut WhSuiMetadata,
        coin: Coin<WHSUI_Token>
          ): u64 {
          balance::decrease_supply(&mut metadata.total_supply, coin::into_balance(coin))
          }
          
          /// Entry: Mint tokens to recipient
          public entry fun mint_tokens(
          metadata: &mut WhSuiMetadata,
          amount: u64,
          recipient: address,
          ctx: &mut TxContext
          ) {
          transfer::public_transfer(mint(metadata, amount, ctx), recipient);
          }
          
          /// Entry: Burn tokens from user
          public entry fun burn_tokens(
          metadata: &mut WhSuiMetadata,
          coin: Coin<WHSUI_Token>
            ) {
            burn(metadata, coin);
            }
            
            /// Get total supply
            public fun total_supply(metadata: &WhSuiMetadata): u64 {
            balance::supply_value(&metadata.total_supply)
            }
            
            // ===== Testing Functions ===== //
            #[test_only]
            public fun test_init(ctx: &mut TxContext) {
            init(WHSUI {}, ctx)
            }
            
            #[test_only]
            public fun test_mint(
            metadata: &mut WhSuiMetadata,
            amount: u64,
            ctx: &mut TxContext
            ): Coin<WHSUI_Token> {
              mint(metadata, amount, ctx)
              }
              
              #[test_only]
              public fun test_burn(
              metadata: &mut WhSuiMetadata,
              coin: Coin<WHSUI_Token>
                ): u64 {
                burn(metadata, coin)
                }
                }
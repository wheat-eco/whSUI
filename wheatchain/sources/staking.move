module wheatchain::staking {
use sui::object::{Self, UID};
use sui::transfer;
use sui::coin::{Self, Coin, TreasuryCap};
use sui::balance::{Self, Balance};
use sui::sui::SUI;
use sui::tx_context::{Self, TxContext};
use wheatchain::token::WHSUI;
use wheatchain::events;

/// The staking pool holding SUI and revenue
public struct StakingPool has key {
id: UID,
total_staked: Balance<SUI>,
  revenue_pool: Balance<SUI>,
    reward_rate: u64, // whSUI per SUI per epoch
    total_rewards_distributed: u64,
    }
    
    /// Receipt for each staker
    public struct StakeReceipt has key, store {
    id: UID,
    staked_amount: u64,
    start_epoch: u64,
    claimed_rewards: u64,
    }
    
    /// Admin capability
    public struct AdminCap has key { id: UID }
    
    /// Initialize the staking pool
    fun init(ctx: &mut TxContext) {
    let pool = StakingPool {
    id: object::new(ctx),
    total_staked: balance::zero(),
    revenue_pool: balance::zero(),
    reward_rate: 1, // 1 whSUI per SUI per epoch
    total_rewards_distributed: 0,
    };
    let admin_cap = AdminCap { id: object::new(ctx) };
    transfer::transfer(pool, tx_context::sender(ctx));
    transfer::transfer(admin_cap, tx_context::sender(ctx));
    }
    
    /// Stake SUI into the pool
    public entry fun stake(
    sui: Coin<SUI>,
      pool: &mut StakingPool,
      ctx: &mut TxContext
      ) {
      let amount = coin::value(&sui);
      let receipt = StakeReceipt {
      id: object::new(ctx),
      staked_amount: amount,
      start_epoch: tx_context::epoch(ctx),
      claimed_rewards: 0,
      };
      balance::join(&mut pool.total_staked, coin::into_balance(sui));
      events::emit_stake_event(tx_context::sender(ctx), amount, tx_context::epoch(ctx));
      transfer::transfer(receipt, tx_context::sender(ctx));
      }
      
      /// Claim accrued whSUI rewards
      public entry fun claim_rewards(
      receipt: &mut StakeReceipt,
      pool: &mut StakingPool,
      treasury: &mut TreasuryCap<WHSUI>,
        ctx: &mut TxContext
        ) {
        let epochs_staked = tx_context::epoch(ctx) - receipt.start_epoch;
        let total_rewards = receipt.staked_amount * pool.reward_rate * epochs_staked;
        let unclaimed_rewards = total_rewards - receipt.claimed_rewards;
        assert!(unclaimed_rewards > 0, 1001); // Error: No rewards to claim
        
        receipt.claimed_rewards = total_rewards;
        pool.total_rewards_distributed = pool.total_rewards_distributed + unclaimed_rewards;
        
        let reward_coin = coin::mint(treasury, unclaimed_rewards, ctx);
        events::emit_reward_claimed_event(tx_context::sender(ctx), unclaimed_rewards);
        transfer::public_transfer(reward_coin, tx_context::sender(ctx));
        }
        
        /// Unstake SUI and claim final rewards
        public entry fun unstake(
        receipt: StakeReceipt,
        pool: &mut StakingPool,
        treasury: &mut TreasuryCap<WHSUI>,
          ctx: &mut TxContext
          ) {
          let epochs_staked = tx_context::epoch(ctx) - receipt.start_epoch;
          let total_rewards = receipt.staked_amount * pool.reward_rate * epochs_staked;
          let unclaimed_rewards = total_rewards - receipt.claimed_rewards;
          
          let StakeReceipt { id, staked_amount, start_epoch: _, claimed_rewards: _ } = receipt;
          let sui = coin::take(&mut pool.total_staked, staked_amount, ctx);
          
          if (unclaimed_rewards > 0) {
          let reward_coin = coin::mint(treasury, unclaimed_rewards, ctx);
          pool.total_rewards_distributed = pool.total_rewards_distributed + unclaimed_rewards;
          events::emit_reward_claimed_event(tx_context::sender(ctx), unclaimed_rewards);
          transfer::public_transfer(reward_coin, tx_context::sender(ctx));
          };
          
          events::emit_unstake_event(tx_context::sender(ctx), staked_amount);
          transfer::public_transfer(sui, tx_context::sender(ctx));
          object::delete(id);
          }
          
          /// Redeem whSUI for SUI (1:1)
          public entry fun redeem(
          whsui: Coin<WHSUI>,
            pool: &mut StakingPool,
            treasury: &mut TreasuryCap<WHSUI>,
              ctx: &mut TxContext
              ) {
              let amount = coin::value(&whsui);
              assert!(balance::value(&pool.revenue_pool) >= amount, 1002); // Error: Insufficient revenue
              coin::burn(treasury, whsui);
              let sui = coin::take(&mut pool.revenue_pool, amount, ctx);
              transfer::public_transfer(sui, tx_context::sender(ctx));
              }
              
              // Getter for reward_rate
              public fun get_reward_rate(pool: &StakingPool): u64 {
              pool.reward_rate
              }
              
              // Setter for reward_rate
              public fun set_reward_rate(pool: &mut StakingPool, new_rate: u64) {
              pool.reward_rate = new_rate;
              }
              
              // Add revenue to the revenue pool
              public fun add_revenue(pool: &mut StakingPool, sui_balance: Balance<SUI>) {
                balance::join(&mut pool.revenue_pool, sui_balance);
                }
                
                // Take SUI from the staking pool
                public fun take_staked_sui(pool: &mut StakingPool, amount: u64, ctx: &mut TxContext): Coin<SUI> {
                  coin::take(&mut pool.total_staked, amount, ctx)
                  }
                  }
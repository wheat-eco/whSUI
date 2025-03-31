module wheatchain::marketplace {
    use std::string::{Self, String};
    use sui::object::{Self, ID, UID};
    use sui::event;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::dynamic_field as df;
    use wheatchain::wheat_nft::{Self, WheatNFT, Collection};

    // ===== Errors =====
    const ENotOwner: u64 = 1;
    const ENotListed: u64 = 2;
    const EAlreadyListed: u64 = 3;
    const EInsufficientPayment: u64 = 4;
    const EInvalidPrice: u64 = 5;

    // ===== Types =====

    /// Marketplace for WheatNFTs
    struct Marketplace has key {
        id: UID,
        owner: address,
        fee_basis_points: u64,
        funds: Balance<SUI>,
    }

    /// Listing information stored as a dynamic field
    struct Listing has store {
        seller: address,
        price: u64,
    }

    // ===== Events =====

    struct NFTListed has copy, drop {
        nft_id: ID,
        seller: address,
        price: u64,
    }

    struct NFTSold has copy, drop {
        nft_id: ID,
        seller: address,
        buyer: address,
        price: u64,
        marketplace_fee: u64,
        royalty_fee: u64,
    }

    struct NFTDelisted has copy, drop {
        nft_id: ID,
        seller: address,
    }

    // ===== Initialization =====

    /// Create a new marketplace
    public entry fun create_marketplace(
        fee_basis_points: u64,
        ctx: &mut TxContext
    ) {
        let marketplace = Marketplace {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            fee_basis_points,
            funds: balance::zero<SUI>(),
        };

        transfer::share_object(marketplace);
    }

    // ===== Marketplace Functions =====

    /// List an NFT for sale
    public entry fun list_nft(
        nft: &mut WheatNFT,
        price: u64,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        
        // Check if NFT is already listed
        assert!(!df::exists_(&nft.id, b"listing"), EAlreadyListed);
        
        // Check if price is valid
        assert!(price > 0, EInvalidPrice);
        
        // Store listing information as a dynamic field
        let listing = Listing {
            seller: sender,
            price,
        };
        
        df::add(&mut nft.id, b"listing", listing);
        
        event::emit(NFTListed {
            nft_id: object::id(nft),
            seller: sender,
            price,
        });
    }

    /// Buy a listed NFT
    public entry fun buy_nft(
        marketplace: &mut Marketplace,
        collection: &mut Collection,
        nft: &mut WheatNFT,
        payment: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let buyer = tx_context::sender(ctx);
        
        // Check if NFT is listed
        assert!(df::exists_(&nft.id, b"listing"), ENotListed);
        
        let listing = df::remove<vector<u8>, Listing>(&mut nft.id, b"listing");
        let Listing { seller, price } = listing;
        
        // Check payment
        assert!(coin::value(&payment) >= price, EInsufficientPayment);
        
        // Calculate fees
        let marketplace_fee = (price * marketplace.fee_basis_points) / 10000;
        let royalty_fee = (price * wheat_nft::royalty_basis_points(collection)) / 10000;
        let seller_amount = price - marketplace_fee - royalty_fee;
        
        // Split payment
        let marketplace_coin = coin::split(&mut payment, marketplace_fee, ctx);
        let royalty_coin = coin::split(&mut payment, royalty_fee, ctx);
        
        // Add marketplace fee to marketplace funds
        coin::put(&mut marketplace.funds, marketplace_coin);
        
        // Add royalty to collection funds
        coin::put(&mut wheat_nft::funds(collection), royalty_coin);
        
        // Transfer remaining payment to seller
        transfer::public_transfer(payment, seller);
        
        event::emit(NFTSold {
            nft_id: object::id(nft),
            seller,
            buyer,
            price,
            marketplace_fee,
            royalty_fee,
        });
    }

    /// Delist an NFT
    public entry fun delist_nft(
        nft: &mut WheatNFT,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        
        // Check if NFT is listed
        assert!(df::exists_(&nft.id, b"listing"), ENotListed);
        
        let listing = df::borrow<vector<u8>, Listing>(&nft.id, b"listing");
        
        // Check if sender is the seller
        assert!(listing.seller == sender, ENotOwner);
        
        let listing = df::remove<vector<u8>, Listing>(&mut nft.id, b"listing");
        let Listing { seller, price: _ } = listing;
        
        event::emit(NFTDelisted {
            nft_id: object::id(nft),
            seller,
        });
    }

    /// Withdraw marketplace fees
    public entry fun withdraw_fees(
        marketplace: &mut Marketplace,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        
        // Check if sender is the marketplace owner
        assert!(marketplace.owner == sender, ENotOwner);
        
        let funds = balance::split(&mut marketplace.funds, amount);
        let coin = coin::from_balance(funds, ctx);
        
        transfer::public_transfer(coin, sender);
    }

    // ===== View Functions =====

    /// Check if an NFT is listed
    public fun is_listed(nft: &WheatNFT): bool {
        df::exists_(&nft.id, b"listing")
    }

    /// Get listing information for an NFT
    public fun listing_info(nft: &WheatNFT): (address, u64) {
        assert!(df::exists_(&nft.id, b"listing"), ENotListed);
        
        let listing = df::borrow<vector<u8>, Listing>(&nft.id, b"listing");
        
        (listing.seller, listing.price)
    }

    /// Get marketplace fee basis points
    public fun fee_basis_points(marketplace: &Marketplace): u64 {
        marketplace.fee_basis_points
    }

    /// Get marketplace owner
    public fun owner(marketplace: &Marketplace): address {
        marketplace.owner
    }
}


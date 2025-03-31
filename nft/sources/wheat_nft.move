module nft::wheat_nft {
    use std::string::{Self, String};
    use std::vector;
    use sui::url::{Self, Url};
    use sui::object::{Self, ID, UID};
    use sui::event;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::package::{Self, Publisher};
    use sui::clock::{Self, Clock};
    use sui::kiosk::{Self, Kiosk, KioskOwnerCap};
    use sui::transfer_policy::{Self, TransferPolicy, TransferPolicyCap};
    use sui::dynamic_field as df;

    // ===== Errors =====
    const ENotAdmin: u64 = 1;
    const ENotOwner: u64 = 2;
    const ENotWhitelisted: u64 = 3;
    const ECollectionNotFound: u64 = 4;
    const EInvalidPrice: u64 = 5;
    const ERoyaltyTooHigh: u64 = 6;
    const EInsufficientPayment: u64 = 7;
    const ERentalPeriodNotOver: u64 = 8;
    const EAlreadyWhitelisted: u64 = 9;
    const ENotRentable: u64 = 10;
    const EAlreadyRented: u64 = 11;
    const ENotRented: u64 = 12;

    // ===== Constants =====
    const MAX_ROYALTY_BASIS_POINTS: u64 = 5000; // 50%
    const SECONDS_IN_DAY: u64 = 86400000; // milliseconds in a day

    // ===== Types =====

    /// Admin capability for the WheatChain NFT ecosystem
    struct AdminCap has key, store {
        id: UID,
    }

    /// Represents a collection of NFTs
    struct Collection has key, store {
        id: UID,
        name: String,
        description: String,
        creator: address,
        symbol: String,
        royalty_basis_points: u64,
        minting_enabled: bool,
        total_supply: u64,
        max_supply: u64,
        base_uri: Url,
        funds: Balance<SUI>,
    }

    /// The NFT token
    struct WheatNFT has key, store {
        id: UID,
        name: String,
        description: String,
        url: Url,
        collection_id: ID,
        token_id: u64,
        attributes: vector<Attribute>,
    }

    /// Attribute for NFT metadata
    struct Attribute has store, copy, drop {
        name: String,
        value: String,
    }

    /// Whitelist for minting privileges
    struct Whitelist has key {
        id: UID,
        collection_id: ID,
        addresses: vector<address>,
    }

    /// Rental information stored as a dynamic field
    struct RentalInfo has store {
        renter: address,
        start_time: u64,
        end_time: u64,
        price_per_day: u64,
        is_active: bool,
    }

    /// Rental receipt given to the renter
    struct RentalReceipt has key, store {
        id: UID,
        nft_id: ID,
        collection_id: ID,
        renter: address,
        owner: address,
        start_time: u64,
        end_time: u64,
        price_paid: u64,
    }

    // ===== Events =====

    struct CollectionCreated has copy, drop {
        collection_id: ID,
        name: String,
        creator: address,
        max_supply: u64,
    }

    struct NFTMinted has copy, drop {
        nft_id: ID,
        collection_id: ID,
        token_id: u64,
        creator: address,
        owner: address,
        name: String,
    }

    struct NFTTransferred has copy, drop {
        nft_id: ID,
        from: address,
        to: address,
    }

    struct NFTRented has copy, drop {
        nft_id: ID,
        owner: address,
        renter: address,
        start_time: u64,
        end_time: u64,
        price_paid: u64,
    }

    struct NFTReturned has copy, drop {
        nft_id: ID,
        owner: address,
        renter: address,
    }

    struct AddressWhitelisted has copy, drop {
        collection_id: ID,
        address: address,
    }

    // ===== Initialization =====

    /// Initialize the module and create the admin capability
    fun init(ctx: &mut TxContext) {
        let admin_cap = AdminCap {
            id: object::new(ctx),
        };
        transfer::transfer(admin_cap, tx_context::sender(ctx));
    }

    // ===== Admin Functions =====

    /// Create a new NFT collection
    public entry fun create_collection(
        _: &AdminCap,
        name: vector<u8>,
        description: vector<u8>,
        symbol: vector<u8>,
        royalty_basis_points: u64,
        max_supply: u64,
        base_uri: vector<u8>,
        ctx: &mut TxContext
    ) {
        // Validate royalty percentage
        assert!(royalty_basis_points <= MAX_ROYALTY_BASIS_POINTS, ERoyaltyTooHigh);

        let collection = Collection {
            id: object::new(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
            creator: tx_context::sender(ctx),
            symbol: string::utf8(symbol),
            royalty_basis_points,
            minting_enabled: true,
            total_supply: 0,
            max_supply,
            base_uri: url::new_unsafe_from_bytes(base_uri),
            funds: balance::zero<SUI>(),
        };

        let collection_id = object::id(&collection);

        // Create a whitelist for this collection
        let whitelist = Whitelist {
            id: object::new(ctx),
            collection_id,
            addresses: vector::empty<address>(),
        };

        event::emit(CollectionCreated {
            collection_id,
            name: collection.name,
            creator: collection.creator,
            max_supply,
        });

        transfer::share_object(collection);
        transfer::share_object(whitelist);
    }

    /// Add an address to the whitelist for a collection
    public entry fun add_to_whitelist(
        _: &AdminCap,
        whitelist: &mut Whitelist,
        addr: address,
        ctx: &mut TxContext
    ) {
        // Check if address is already whitelisted
        let (exists, _) = vector::index_of(&whitelist.addresses, &addr);
        assert!(!exists, EAlreadyWhitelisted);

        vector::push_back(&mut whitelist.addresses, addr);

        event::emit(AddressWhitelisted {
            collection_id: whitelist.collection_id,
            address: addr,
        });
    }

    /// Toggle minting for a collection
    public entry fun toggle_minting(
        _: &AdminCap,
        collection: &mut Collection,
        enabled: bool,
        _ctx: &mut TxContext
    ) {
        collection.minting_enabled = enabled;
    }

    /// Withdraw funds from a collection
    public entry fun withdraw_funds(
        _: &AdminCap,
        collection: &mut Collection,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let funds = balance::split(&mut collection.funds, amount);
        let coin = coin::from_balance(funds, ctx);
        transfer::public_transfer(coin, tx_context::sender(ctx));
    }

    // ===== Minting Functions =====

    /// Mint a new NFT (admin only)
    public entry fun mint_nft(
        _: &AdminCap,
        collection: &mut Collection,
        recipient: address,
        name: vector<u8>,
        description: vector<u8>,
        uri_suffix: vector<u8>,
        attributes: vector<vector<u8>>,
        attribute_values: vector<vector<u8>>,
        ctx: &mut TxContext
    ) {
        // Check if minting is enabled
        assert!(collection.minting_enabled, ENotAdmin);
        
        // Check if max supply is reached
        assert!(collection.total_supply < collection.max_supply, ENotAdmin);

        // Increment token ID
        let token_id = collection.total_supply;
        collection.total_supply = collection.total_supply + 1;

        // Construct the full URI
        let full_uri_bytes = vector::empty<u8>();
        vector::append(&mut full_uri_bytes, *string::bytes(&url::inner_url(&collection.base_uri)));
        vector::append(&mut full_uri_bytes, uri_suffix);

        // Create the NFT
        let nft = WheatNFT {
            id: object::new(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
            url: url::new_unsafe_from_bytes(full_uri_bytes),
            collection_id: object::id(collection),
            token_id,
            attributes: create_attributes(attributes, attribute_values),
        };

        let nft_id = object::id(&nft);

        event::emit(NFTMinted {
            nft_id,
            collection_id: object::id(collection),
            token_id,
            creator: collection.creator,
            owner: recipient,
            name: nft.name,
        });

        transfer::public_transfer(nft, recipient);
    }

    /// Mint a new NFT (whitelisted users)
    public entry fun mint_from_whitelist(
        collection: &mut Collection,
        whitelist: &Whitelist,
        payment: Coin<SUI>,
        name: vector<u8>,
        description: vector<u8>,
        uri_suffix: vector<u8>,
        attributes: vector<vector<u8>>,
        attribute_values: vector<vector<u8>>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        
        // Check if collection IDs match
        assert!(object::id(collection) == whitelist.collection_id, ECollectionNotFound);
        
        // Check if sender is whitelisted
        let (is_whitelisted, _) = vector::index_of(&whitelist.addresses, &sender);
        assert!(is_whitelisted, ENotWhitelisted);
        
        // Check if minting is enabled
        assert!(collection.minting_enabled, ENotAdmin);
        
        // Check if max supply is reached
        assert!(collection.total_supply < collection.max_supply, ENotAdmin);

        // Handle payment
        let payment_value = coin::value(&payment);
        coin::put(&mut collection.funds, payment);

        // Increment token ID
        let token_id = collection.total_supply;
        collection.total_supply = collection.total_supply + 1;

        // Construct the full URI
        let full_uri_bytes = vector::empty<u8>();
        vector::append(&mut full_uri_bytes, *string::bytes(&url::inner_url(&collection.base_uri)));
        vector::append(&mut full_uri_bytes, uri_suffix);

        // Create the NFT
        let nft = WheatNFT {
            id: object::new(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
            url: url::new_unsafe_from_bytes(full_uri_bytes),
            collection_id: object::id(collection),
            token_id,
            attributes: create_attributes(attributes, attribute_values),
        };

        let nft_id = object::id(&nft);

        event::emit(NFTMinted {
            nft_id,
            collection_id: object::id(collection),
            token_id,
            creator: collection.creator,
            owner: sender,
            name: nft.name,
        });

        transfer::public_transfer(nft, sender);
    }

    // ===== NFT Functions =====

    /// Transfer an NFT to a new owner
    public entry fun transfer_nft(
        nft: WheatNFT,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let nft_id = object::id(&nft);
        let sender = tx_context::sender(ctx);

        event::emit(NFTTransferred {
            nft_id,
            from: sender,
            to: recipient,
        });

        transfer::public_transfer(nft, recipient);
    }

    /// Update the description of an NFT
    public entry fun update_description(
        nft: &mut WheatNFT,
        new_description: vector<u8>,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == tx_context::sender(ctx), ENotOwner);
        nft.description = string::utf8(new_description);
    }

    // ===== Rental Functions =====

    /// List an NFT for rental
    public entry fun list_for_rental(
        nft: &mut WheatNFT,
        price_per_day: u64,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        
        // Check if NFT is already rented
        assert!(!df::exists_(&nft.id, b"rental_info"), EAlreadyRented);

        // Store rental information as a dynamic field
        let rental_info = RentalInfo {
            renter: @0x0, // No renter yet
            start_time: 0,
            end_time: 0,
            price_per_day,
            is_active: false,
        };

        df::add(&mut nft.id, b"rental_info", rental_info);
    }

    /// Rent an NFT
    public entry fun rent_nft(
        nft: &mut WheatNFT,
        payment: Coin<SUI>,
        rental_days: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        
        // Check if NFT is available for rental
        assert!(df::exists_(&nft.id, b"rental_info"), ENotRentable);
        
        let rental_info = df::borrow_mut<vector<u8>, RentalInfo>(&mut nft.id, b"rental_info");
        
        // Check if NFT is not already rented
        assert!(!rental_info.is_active, EAlreadyRented);
        
        // Calculate total price
        let total_price = rental_info.price_per_day * rental_days;
        
        // Check payment
        assert!(coin::value(&payment) >= total_price, EInsufficientPayment);
        
        // Get current time
        let current_time = clock::timestamp_ms(clock);
        
        // Update rental info
        rental_info.renter = sender;
        rental_info.start_time = current_time;
        rental_info.end_time = current_time + (rental_days * SECONDS_IN_DAY);
        rental_info.is_active = true;
        
        // Create rental receipt
        let receipt = RentalReceipt {
            id: object::new(ctx),
            nft_id: object::id(nft),
            collection_id: nft.collection_id,
            renter: sender,
            owner: tx_context::sender(ctx),
            start_time: current_time,
            end_time: current_time + (rental_days * SECONDS_IN_DAY),
            price_paid: total_price,
        };
        
        // Transfer payment to owner
        transfer::public_transfer(payment, tx_context::sender(ctx));
        
        // Transfer receipt to renter
        transfer::public_transfer(receipt, sender);
        
        event::emit(NFTRented {
            nft_id: object::id(nft),
            owner: tx_context::sender(ctx),
            renter: sender,
            start_time: current_time,
            end_time: current_time + (rental_days * SECONDS_IN_DAY),
            price_paid: total_price,
        });
    }

    /// Return a rented NFT
    public entry fun return_nft(
        nft: &mut WheatNFT,
        receipt: RentalReceipt,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        
        // Check if NFT is rented
        assert!(df::exists_(&nft.id, b"rental_info"), ENotRentable);
        
        let rental_info = df::borrow_mut<vector<u8>, RentalInfo>(&mut nft.id, b"rental_info");
        
        // Check if NFT is currently rented
        assert!(rental_info.is_active, ENotRented);
        
        // Check if sender is the renter
        assert!(rental_info.renter == sender, ENotOwner);
        
        // Check if receipt matches NFT
        assert!(receipt.nft_id == object::id(nft), ENotOwner);
        
        // Reset rental info
        rental_info.is_active = false;
        
        // Delete receipt
        let RentalReceipt {
            id,
            nft_id: _,
            collection_id: _,
            renter: _,
            owner,
            start_time: _,
            end_time: _,
            price_paid: _,
        } = receipt;
        
        object::delete(id);
        
        event::emit(NFTReturned {
            nft_id: object::id(nft),
            owner,
            renter: sender,
        });
    }

    /// Reclaim an NFT after rental period is over
    public entry fun reclaim_nft(
        nft: &mut WheatNFT,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        
        // Check if NFT is rented
        assert!(df::exists_(&nft.id, b"rental_info"), ENotRentable);
        
        let rental_info = df::borrow_mut<vector<u8>, RentalInfo>(&mut nft.id, b"rental_info");
        
        // Check if NFT is currently rented
        assert!(rental_info.is_active, ENotRented);
        
        // Check if rental period is over
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time > rental_info.end_time, ERentalPeriodNotOver);
        
        // Reset rental info
        rental_info.is_active = false;
        
        event::emit(NFTReturned {
            nft_id: object::id(nft),
            owner: sender,
            renter: rental_info.renter,
        });
    }

    // ===== Helper Functions =====

    /// Create attributes from name-value pairs
    fun create_attributes(
        names: vector<vector<u8>>,
        values: vector<vector<u8>>
    ): vector<Attribute> {
        let len = vector::length(&names);
        assert!(len == vector::length(&values), 0);
        
        let i = 0;
        let attributes = vector::empty<Attribute>();
        
        while (i < len) {
            let name = vector::borrow(&names, i);
            let value = vector::borrow(&values, i);
            
            vector::push_back(&mut attributes, Attribute {
                name: string::utf8(*name),
                value: string::utf8(*value),
            });
            
            i = i + 1;
        };
        
        attributes
    }

    // ===== View Functions =====

    /// Get the name of an NFT
    public fun name(nft: &WheatNFT): &String {
        &nft.name
    }

    /// Get the description of an NFT
    public fun description(nft: &WheatNFT): &String {
        &nft.description
    }

    /// Get the URL of an NFT
    public fun url(nft: &WheatNFT): &Url {
        &nft.url
    }

    /// Get the collection ID of an NFT
    public fun collection_id(nft: &WheatNFT): ID {
        nft.collection_id
    }

    /// Get the token ID of an NFT
    public fun token_id(nft: &WheatNFT): u64 {
        nft.token_id
    }

    /// Check if an address is whitelisted
    public fun is_whitelisted(whitelist: &Whitelist, addr: address): bool {
        let (exists, _) = vector::index_of(&whitelist.addresses, &addr);
        exists
    }

    /// Check if an NFT is available for rental
    public fun is_rentable(nft: &WheatNFT): bool {
        df::exists_(&nft.id, b"rental_info")
    }

    /// Check if an NFT is currently rented
    public fun is_rented(nft: &WheatNFT): bool {
        if (df::exists_(&nft.id, b"rental_info")) {
            let rental_info = df::borrow<vector<u8>, RentalInfo>(&nft.id, b"rental_info");
            rental_info.is_active
        } else {
            false
        }
    }

    /// Get rental information for an NFT
    public fun rental_info(nft: &WheatNFT): (address, u64, u64, u64, bool) {
        assert!(df::exists_(&nft.id, b"rental_info"), ENotRentable);
        
        let rental_info = df::borrow<vector<u8>, RentalInfo>(&nft.id, b"rental_info");
        
        (
            rental_info.renter,
            rental_info.start_time,
            rental_info.end_time,
            rental_info.price_per_day,
            rental_info.is_active
        )
    }
}


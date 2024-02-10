import Base "mo:base/Compat";
import Blob "mo:base/Blob";
import Text "mo:base/Text";
import Principal "mo:base/Principal";

actor Senceh {
    type TokenData = { tokenId : Nat; tokenURI : Text };

    type ERC721Metadata = { name : Text; symbol : Text };

    type ERC721Event =
        | MintFeeUpdated(Nat)
        | Transfer(Principal, Principal, Nat)
        | Approval(Principal, Principal, Nat);

    type ERC721Error = {
        code : Nat;
        message : Text;
    };

    type ERC721Storage = {
        tokens : Trie<TokenData>;
        balances : Trie<Nat>;
        mintFee : Nat;
    };

    public shared({name, symbol} : ERC721Metadata, initialOwner : Principal, mintFee : Nat) : async Senceh {
        let tokens = Trie.empty<TokenData>();
        let balances = Trie.empty<Nat>();
        let storage = { tokens = tokens; balances = balances; mintFee = mintFee };
        Senceh { metadata = { name = name; symbol = symbol }; owner = initialOwner; storage = storage }
    };

    public func mintFee() : async Nat {
        storage.mintFee
    };

    public func setMintFee(newMintFee : Nat) : async () {
        storage.mintFee := newMintFee;
        let event = MintFeeUpdated(newMintFee);
        Senceh.handleEvent(event);
    };

    public func safeMint(to : Principal, tokenId : Nat, tokenURI : Text) : async () {
        let sender = Principal.fromActor(this);
        let mintFee = await self.mintFee();
        let senderBalance = switch (storage.balances.find(sender)) {
            null => 0;
            some(balance) => balance;
        };

        if (senderBalance < mintFee) {
            // Handle insufficient payment for mint fee
            return;
        }

        let newTokenData = { tokenId = tokenId; tokenURI = tokenURI };
        storage.tokens := Trie.put<TokenData>(storage.tokens, tokenId, newTokenData);

        // Increase balance of recipient
        storage.balances := Trie.insert<Nat>(storage.balances, to, 1);

        // Decrease balance of sender by mint fee
        storage.balances := Trie.update<Nat>(storage.balances, sender, senderBalance - mintFee);

        // Emit Transfer event
        let event = Transfer(sender, to, tokenId);
        Senceh.handleEvent(event);
    };

    public func userMint(to : Principal, tokenId : Nat, tokenURI : Text) : async () {
        let mintFee = await self.mintFee();
        let senderBalance = switch (Senceh.balance()) {
            null => 0;
            some(balance) => balance;
        };

        if (senderBalance < mintFee) {
            // Handle insufficient payment for mint fee
            return;
        }

        // Call safeMint with the specified parameters
        await self.safeMint(to, tokenId, tokenURI);
    };

    public query func balance() : async ?Nat {
        let sender = Principal.fromActor(this);
        storage.balances.find(sender);
    };

    public query func tokenURI(tokenId : Nat) : async ?Text {
        storage.tokens.find(tokenId).map((tokenData) => tokenData.tokenURI);
    };

    public query func getAllTokenData() : async [TokenData] {
        Trie.toList(storage.tokens);
    };

    // Owner-related functions

    public func updateMintFee(newMintFee : Nat) : async () {
        assert Principal.equal(owner, Principal.fromActor(this));
        await self.setMintFee(newMintFee);
    };

    public query func owner() : async Principal {
        storage.owner;
    };

    public func transferOwnership(newOwner : Principal) : async () {
        assert Principal.equal(owner, Principal.fromActor(this));
        storage.owner := newOwner;
    };

    // Handling events
    public func handleEvent(event : ERC721Event) : async () {
        switch (event) {
            case (MintFeeUpdated(newMintFee)) {
                // Handle MintFeeUpdated event
            };
            case (Transfer(_, _, _)) {
                // Handle Transfer event
            };
            case (Approval(_, _, _)) {
                // Handle Approval event
            };
        };
    };

    // Storage
    private var metadata : ERC721Metadata;
    private var owner : Principal;
    private var storage : ERC721Storage;
};

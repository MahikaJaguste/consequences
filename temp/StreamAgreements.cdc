import FungibleToken from "./FungibleToken.cdc"

pub contract StreamToken : FungibleToken {

    /// Total supply of StreamTokens in existence
    pub var totalSupply: UFix64

    /// Storage and Public Paths
    pub let VaultStoragePath: StoragePath
    pub let ReceiverPublicPath: PublicPath
    pub let BalancePublicPath: PublicPath
    pub let ProviderPrivatePath: PrivatePath
    pub let AdminStoragePath: StoragePath
    pub let MinterStoragePath: StoragePath

    /// TokensInitialized
    ///
    /// The event that is emitted when the contract is created
    pub event TokensInitialized(initialSupply: UFix64)

    /// TokensWithdrawn
    ///
    /// The event that is emitted when tokens are withdrawn from a Vault
    pub event TokensWithdrawn(amount: UFix64, from: Address?)

    /// TokensDeposited
    ///
    /// The event that is emitted when tokens are deposited to a Vault
    pub event TokensDeposited(amount: UFix64, to: Address?)

    /// TokensMinted
    ///
    /// The event that is emitted when new tokens are minted
    pub event TokensMinted(amount: UFix64)

    /// TokensBurned
    ///
    /// The event that is emitted when tokens are destroyed
    pub event TokensBurned(amount: UFix64)

    /// MinterCreated
    ///
    /// The event that is emitted when a new minter resource is created
    pub event MinterCreated(allowedAmount: UFix64)

    /// BurnerCreated
    ///
    /// The event that is emitted when a new burner resource is created
    pub event BurnerCreated()

    /// Vault
    ///
    /// Each user stores an instance of only the Vault in their storage
    /// The functions in the Vault and governed by the pre and post conditions
    /// in FungibleToken when they are called.
    /// The checks happen at runtime whenever a function is called.
    ///
    /// Resources can only be created in the context of the contract that they
    /// are defined in, so there is no way for a malicious user to create Vaults
    /// out of thin air. A special Minter resource needs to be defined to mint
    /// new tokens.
    ///
    pub resource Vault: FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance {

        /// The total balance of this vault
        pub var balance: UFix64

        pub var latestTimeElapsed: UFix64
        pub var netFlowRate: UFix64

        // initialize the balance at resource creation time
        init(balance: UFix64) {
            self.balance = balance
            self.latestTimeElapsed = 0.0
            self.netFlowRate = 0.0
        }

        /// withdraw
        ///
        /// Function that takes an amount as an argument
        /// and withdraws that amount from the Vault.
        ///
        /// It creates a new temporary Vault that is used to hold
        /// the money that is being transferred. It returns the newly
        /// created Vault to the context that called so it can be deposited
        /// elsewhere.
        ///
        pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
            let currentTimestamp = getCurrentBlock().timestamp
            let realTimeBalance  = self.getRealTimeBalance_(currentTimestamp: currentTimestamp)

            if(realTimeBalance < amount) {
                panic("Insufficient funds")
            }

            self.latestTimeElapsed = currentTimestamp
            self.balance = realTimeBalance - amount
            
            emit TokensWithdrawn(amount: amount, from: self.owner?.address)
            return <-create Vault(balance: amount)
        }

        /// deposit
        ///
        /// Function that takes a Vault object as an argument and adds
        /// its balance to the balance of the owners Vault.
        ///
        /// It is allowed to destroy the sent Vault because the Vault
        /// was a temporary holder of the tokens. The Vault's balance has
        /// been consumed and therefore can be destroyed.
        ///
        pub fun deposit(from: @FungibleToken.Vault) {
            let vault <- from as! @StreamToken.Vault
            self.balance = self.balance + vault.balance
            emit TokensDeposited(amount: vault.balance, to: self.owner?.address)
            vault.balance = 0.0
            destroy vault
        }

        destroy() {
            if self.balance > 0.0 {
                StreamToken.totalSupply = StreamToken.totalSupply - self.balance
            }
        }

        pub fun getRealTimeBalance(): UFix64 {
            let currentTimestamp = getCurrentBlock().timestamp
            return self.getRealTimeBalance_(currentTimestamp: currentTimestamp)     
        }

        pub fun getRealTimeBalance_(currentTimestamp: UFix64): UFix64 {
            let timeElapsed = currentTimestamp - self.latestTimeElapsed
            let timeElapsedCost = timeElapsed * self.netFlowRate
            let realTimeBalance = self.balance + timeElapsedCost
            if(realTimeBalance < 0.0) {
                return 0.0
            }
            return realTimeBalance
        }
               
    }

    /// createEmptyVault
    ///
    /// Function that creates a new Vault with a balance of zero
    /// and returns it to the calling context. A user must call this function
    /// and store the returned Vault in their storage in order to allow their
    /// account to be able to receive deposits of this token type.
    ///
    pub fun createEmptyVault(): @Vault {
        return <-create Vault(balance: 0.0)
    }

    pub resource Stream {

        pub var latestTimeElapsed: UFix64
        pub var netFlowRate: UFix64
        pub var isActive: Bool
        pub var balanceOwed: UFix64

        init(netFlowRate: UFix64) {
            self.latestTimeElapsed = getCurrentBlock().timestamp
            self.balanceOwed = 0.0
            self.netFlowRate = netFlowRate
            self.isActive = true
        }

        pub fun getRealTimeBalance(): UFix64 {
            if(!self.isActive) {
                return self.balanceOwed
            }
            let currentTimestamp: UFix64 = getCurrentBlock().timestamp
            return self.getRealTimeBalance_(currentTimestamp: currentTimestamp)     
        }

        access(self) fun getRealTimeBalance_(currentTimestamp: UFix64): UFix64 {
            let timeElapsed: UFix64 = currentTimestamp - self.latestTimeElapsed
            let timeElapsedCost: UFix64 = timeElapsed * self.netFlowRate
            if(timeElapsedCost < 0.0) {
                return 0.0
            }
            return timeElapsedCost
        }

        pub fun stop() {
            if(!self.isActive) {
                panic("Stream is already stopped")
            }
            self.balanceOwed = self.getRealTimeBalance()
            self.isActive = false
        }
        
    }

    pub resource Administrator {

        /// createNewMinter
        ///
        /// Function that creates and returns a new minter resource
        ///
        pub fun createNewMinter(allowedAmount: UFix64): @Minter {
            emit MinterCreated(allowedAmount: allowedAmount)
            return <-create Minter(allowedAmount: allowedAmount)
        }

        /// createNewBurner
        ///
        /// Function that creates and returns a new burner resource
        ///
        pub fun createNewBurner(): @Burner {
            emit BurnerCreated()
            return <-create Burner()
        }
    }

    /// Minter
    ///
    /// Resource object that token admin accounts can hold to mint new tokens.
    ///
    pub resource Minter {

        /// The amount of tokens that the minter is allowed to mint
        pub var allowedAmount: UFix64

        /// mintTokens
        ///
        /// Function that mints new tokens, adds them to the total supply,
        /// and returns them to the calling context.
        ///
        pub fun mintTokens(amount: UFix64): @StreamToken.Vault {
            pre {
                amount > 0.0: "Amount minted must be greater than zero"
                amount <= self.allowedAmount: "Amount minted must be less than the allowed amount"
            }
            StreamToken.totalSupply = StreamToken.totalSupply + amount
            self.allowedAmount = self.allowedAmount - amount
            emit TokensMinted(amount: amount)
            return <-create Vault(balance: amount)
        }

        init(allowedAmount: UFix64) {
            self.allowedAmount = allowedAmount
        }
    }

    /// Burner
    ///
    /// Resource object that token admin accounts can hold to burn tokens.
    ///
    pub resource Burner {

        /// burnTokens
        ///
        /// Function that destroys a Vault instance, effectively burning the tokens.
        ///
        /// Note: the burned tokens are automatically subtracted from the
        /// total supply in the Vault destructor.
        ///
        pub fun burnTokens(from: @FungibleToken.Vault) {
            let vault <- from as! @StreamToken.Vault
            let amount = vault.balance
            destroy vault
            emit TokensBurned(amount: amount)
        }
    }

    init() {
        self.totalSupply = 0.0

        self.VaultStoragePath = /storage/StreamTokenVault
        self.ReceiverPublicPath = /public/StreamTokenReceiver
        self.ProviderPrivatePath = /private/StreamTokenProvider
        self.BalancePublicPath = /public/StreamTokenBalance
        self.AdminStoragePath = /storage/StreamTokenAdmin
        self.MinterStoragePath = /storage/StreamTokenMinter

        // Create the Vault with the total supply of tokens and save it in storage
        //
        let vault <- create Vault(balance: self.totalSupply)
        self.account.save(<-vault, to: self.VaultStoragePath)

        // Create a public capability to the stored Vault that only exposes
        // the `deposit` method through the `Receiver` interface
        //
        self.account.link<&{FungibleToken.Receiver}>(
            self.ReceiverPublicPath,
            target: self.VaultStoragePath
        )

        // Create a public capability to the stored Vault that only exposes
        // the `balance` field through the `Balance` interface
        //
        self.account.link<&StreamToken.Vault{FungibleToken.Balance}>(
            self.BalancePublicPath,
            target: self.VaultStoragePath
        )

        let admin <- create Administrator()
        self.account.save(<-admin, to: self.AdminStoragePath)

        // Emit an event that shows that the contract was initialized
        //
        emit TokensInitialized(initialSupply: self.totalSupply)
    }
}
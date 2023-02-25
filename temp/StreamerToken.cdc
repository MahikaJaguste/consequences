import StreamerFungibleToken from "./StreamerFungibleToken.cdc"
import FungibleToken from "./FungibleToken.cdc"

pub contract StreamerToken {

    pub var totalSupply: UFix64

    pub let VaultStoragePath: StoragePath
    pub let ReceiverPublicPath: PublicPath
    pub let BalancePublicPath: PublicPath
    pub let ProviderPrivatePath: PrivatePath
    pub let AdminStoragePath: StoragePath
    pub let MinterStoragePath: StoragePath

    pub event TokensInitialized(initialSupply: UFix64)
    pub event TokensWithdrawn(amount: UFix64, from: Address?)
    pub event TokensDeposited(amount: UFix64, to: Address?)

    pub event TokensMinted(amount: UFix64)
    pub event TokensBurned(amount: UFix64)

  
    pub event MinterCreated(allowedAmount: UFix64)
    pub event BurnerCreated()

    
    pub resource StreamerVault {

        pub var staticBalance: UFix64
        pub var latestTimeElapsed: UFix64
        pub var netFlowRate: UFix64

        init(balance: UFix64) {
            self.staticBalance = balance
            self.latestTimeElapsed = 0.0
            self.netFlowRate = 0.0
        }

        pub fun withdraw(amount: UFix64): @StreamerVault {
            let currentTimestamp = getCurrentBlock().timestamp
            let realTimeBalance  = self.getRealTimeBalance(currentTimestamp: currentTimestamp)

            if(realTimeBalance < amount) {
                panic("Insufficient funds")
            }

            self.latestTimeElapsed = currentTimestamp
            self.staticBalance = realTimeBalance - amount
            
            emit TokensWithdrawn(amount: amount, from: self.owner?.address)
            return <-create StreamerVault(balance: amount)
        }


        pub fun deposit(from: @StreamerVault) {
            let vault <- from
            self.staticBalance = self.staticBalance + vault.staticBalance
            emit TokensDeposited(amount: vault.staticBalance, to: self.owner?.address)
            destroy vault
        }

        pub fun getBalance(): UFix64 {
            let currentTimestamp = getCurrentBlock().timestamp
            return self.getRealTimeBalance(currentTimestamp: currentTimestamp)
            
        }

        pub fun getRealTimeBalance(currentTimestamp: UFix64): UFix64 {
            let timeElapsed = currentTimestamp - self.latestTimeElapsed
            let timeElapsedCost = timeElapsed * self.netFlowRate
            let realTimeBalance = self.staticBalance + timeElapsedCost
            if(realTimeBalance < 0.0) {
                return 0.0
            }
            return realTimeBalance

        }

        pub fun setNetFlowRate(newRate: UFix64) {
            self.netFlowRate = newRate
        }

        pub fun createEmptyStreamerVault(): @StreamerVault {
            return <-create StreamerVault(balance: 0.0)
        }


        // destroy() {
        //     if self.balance > 0.0 {
        //         TicketToken.totalSupply = TicketToken.totalSupply - self.balance
        //     }
        // }
        /// The way of getting all the Metadata Views implemented by ExampleToken
        ///
        /// @return An array of Types defining the implemented views. This value will be used by
        ///         developers to know which parameter to pass to the resolveView() method.
        ///
        /// pub fun getViews(): [Type]{
        ///     return [Type<FungibleTokenMetadataViews.FTView>(),
        ///             Type<FungibleTokenMetadataViews.FTDisplay>(),
        ///             Type<FungibleTokenMetadataViews.FTVaultData>()]
        /// }
        /// The way of getting a Metadata View out of the ExampleToken
        ///
        /// @param view: The Type of the desired view.
        /// @return A structure representing the requested view.
        ///
             
    }

    /// createEmptyVault
    ///
    /// Function that creates a new Vault with a balance of zero
    /// and returns it to the calling context. A user must call this function
    /// and store the returned Vault in their storage in order to allow their
    /// account to be able to receive deposits of this token type.
    ///
    pub fun createEmptyStreamerVault(): @StreamerVault {
        return <-create StreamerVault(balance: 0.0)
    }

    init() {
        self.totalSupply = 0.0

        self.VaultStoragePath = /storage/TicketTokenVault
        self.ReceiverPublicPath = /public/TicketTokenReceiver
        self.ProviderPrivatePath = /private/TicketTokenProvider
        self.BalancePublicPath = /public/TicketTokenBalance
        self.AdminStoragePath = /storage/TicketTokenAdmin
        self.MinterStoragePath = /storage/TicketTokenMinter

        // Create the Vault with the total supply of tokens and save it in storage
        //
        let vault <- create StreamerVault(balance: self.totalSupply)
        self.account.save(<-vault, to: self.VaultStoragePath)

        // Create a public capability to the stored Vault that only exposes
        // the `deposit` method through the `Receiver` interface
        //
        // self.account.link<&{FungibleToken.Receiver}>(
        //     self.ReceiverPublicPath,
        //     target: self.VaultStoragePath
        // )

        // Create a public capability to the stored Vault that only exposes
        // the `balance` field through the `Balance` interface
        //
        // self.account.link<&TicketToken.Vault{FungibleToken.Balance}>(
        //     self.BalancePublicPath,
        //     target: self.VaultStoragePath
        // )

        
        emit TokensInitialized(initialSupply: self.totalSupply)
    }
}
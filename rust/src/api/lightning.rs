use flutter_rust_bridge::frb;
use lni::{
    CreateInvoiceParams as LniCreateInvoiceParams, InvoiceType, LightningNode,
    ListTransactionsParams as LniListTransactionsParams, LookupInvoiceParams,
    PayInvoiceParams as LniPayInvoiceParams,
};
use lni::strike::{StrikeConfig, StrikeNode};
use lni::nwc::{NwcConfig, NwcNode};

use crate::api::error::ApiError;

/// Configuration for Strike Lightning payments
#[frb(non_opaque)]
#[derive(Debug, Clone)]
pub struct StrikeLightningConfig {
    /// Strike API key for authentication
    pub api_key: String,
    /// Optional custom base URL (defaults to https://api.strike.me/v1)
    pub base_url: Option<String>,
    /// Optional SOCKS5 proxy URL for Tor support
    pub socks5_proxy: Option<String>,
    /// Whether to accept invalid SSL certificates (for development)
    pub accept_invalid_certs: Option<bool>,
    /// HTTP timeout in seconds
    pub http_timeout: Option<i64>,
}

impl From<StrikeLightningConfig> for StrikeConfig {
    fn from(config: StrikeLightningConfig) -> Self {
        StrikeConfig {
            api_key: config.api_key,
            base_url: config.base_url,
            socks5_proxy: config.socks5_proxy,
            accept_invalid_certs: config.accept_invalid_certs,
            http_timeout: config.http_timeout,
        }
    }
}

/// Lightning node information
#[frb(non_opaque)]
#[derive(Debug, Clone)]
pub struct LightningNodeInfo {
    /// Node alias/name
    pub alias: String,
    /// Node public key
    pub public_key: String,
    /// Total send balance in millisatoshis
    pub send_balance_msats: i64,
    /// Total receive balance in millisatoshis  
    pub receive_balance_msats: i64,
}

/// Lightning invoice/transaction
#[frb(non_opaque)]
#[derive(Debug, Clone)]
pub struct LightningTransaction {
    /// Transaction type
    pub type_: String,
    /// Invoice/payment request string
    pub invoice: String,
    /// Payment hash
    pub payment_hash: String,
    /// Amount in millisatoshis
    pub amount_msats: i64,
    /// Transaction description/memo
    pub description: String,
    /// Creation timestamp
    pub created_at: i64,
    /// Expiration timestamp
    pub expires_at: i64,
    /// Settlement timestamp (0 if not paid)
    pub settled_at: i64,
    /// Fees paid in millisatoshis
    pub fees_paid: i64,
}

/// Parameters for creating a Lightning invoice
#[frb(non_opaque)]
#[derive(Debug, Clone)]
pub struct CreateInvoiceParams {
    /// Amount in millisatoshis
    pub amount_msats: Option<i64>,
    /// Invoice description/memo
    pub description: Option<String>,
    /// Expiry time in seconds
    pub expiry: Option<i64>,
}

/// Parameters for paying a Lightning invoice
#[frb(non_opaque)]
#[derive(Debug, Clone)]
pub struct PayInvoiceParams {
    /// BOLT11 invoice string to pay
    pub invoice: String,
    /// Maximum fee percentage (e.g., 1.0 for 1%)
    pub fee_limit_percentage: Option<f64>,
}

/// Response from paying an invoice
#[frb(non_opaque)]
#[derive(Debug, Clone)]
pub struct PayInvoiceResponse {
    /// Payment hash
    pub payment_hash: String,
    /// Payment preimage
    pub preimage: String,
    /// Fee paid in millisatoshis
    pub fee_msats: i64,
}

/// Parameters for listing transactions
#[frb(non_opaque)]
#[derive(Debug, Clone)]
pub struct ListTransactionsParams {
    /// Offset for pagination
    pub from: i64,
    /// Limit number of results
    pub limit: i64,
    /// Optional search filter
    pub search: Option<String>,
}

/// Get Strike node information including balance
#[frb]
pub async fn strike_get_info(config: StrikeLightningConfig) -> Result<LightningNodeInfo, ApiError> {
    let strike_config: StrikeConfig = config.into();
    let node = StrikeNode::new(strike_config);
    
    let info = node.get_info().await.map_err(|e| {
        ApiError::LightningError(format!("Failed to get Strike node info: {}", e))
    })?;

    Ok(LightningNodeInfo {
        alias: info.alias,
        public_key: info.pubkey,
        send_balance_msats: info.send_balance_msat,
        receive_balance_msats: info.receive_balance_msat,
    })
}

/// Create a Lightning invoice with Strike
#[frb]
pub async fn strike_create_invoice(
    config: StrikeLightningConfig,
    params: CreateInvoiceParams,
) -> Result<LightningTransaction, ApiError> {
    let strike_config: StrikeConfig = config.into();
    let node = StrikeNode::new(strike_config);

    let lni_params = LniCreateInvoiceParams {
        invoice_type: InvoiceType::Bolt11,
        amount_msats: params.amount_msats,
        description: params.description,
        expiry: params.expiry,
        ..Default::default()
    };

    let transaction = node.create_invoice(lni_params).await.map_err(|e| {
        ApiError::LightningError(format!("Failed to create invoice: {}", e))
    })?;

    Ok(LightningTransaction {
        type_: transaction.type_,
        invoice: transaction.invoice,
        payment_hash: transaction.payment_hash,
        amount_msats: transaction.amount_msats,
        description: transaction.description,
        created_at: transaction.created_at,
        expires_at: transaction.expires_at,
        settled_at: transaction.settled_at,
        fees_paid: transaction.fees_paid,
    })
}

/// Pay a Lightning invoice with Strike
#[frb]
pub async fn strike_pay_invoice(
    config: StrikeLightningConfig,
    params: PayInvoiceParams,
) -> Result<PayInvoiceResponse, ApiError> {
    let strike_config: StrikeConfig = config.into();
    let node = StrikeNode::new(strike_config);

    let lni_params = LniPayInvoiceParams {
        invoice: params.invoice,
        fee_limit_percentage: params.fee_limit_percentage,
        ..Default::default()
    };

    let response = node.pay_invoice(lni_params).await.map_err(|e| {
        ApiError::LightningError(format!("Failed to pay invoice: {}", e))
    })?;

    Ok(PayInvoiceResponse {
        payment_hash: response.payment_hash,
        preimage: response.preimage,
        fee_msats: response.fee_msats,
    })
}

/// Lookup a Lightning invoice by payment hash
#[frb]
pub async fn strike_lookup_invoice(
    config: StrikeLightningConfig,
    payment_hash: String,
) -> Result<LightningTransaction, ApiError> {
    let strike_config: StrikeConfig = config.into();
    let node = StrikeNode::new(strike_config);

    let params = LookupInvoiceParams {
        payment_hash: Some(payment_hash),
        ..Default::default()
    };

    let transaction = node.lookup_invoice(params).await.map_err(|e| {
        ApiError::LightningError(format!("Failed to lookup invoice: {}", e))
    })?;

    Ok(LightningTransaction {
        type_: transaction.type_,
        invoice: transaction.invoice,
        payment_hash: transaction.payment_hash,
        amount_msats: transaction.amount_msats,
        description: transaction.description,
        created_at: transaction.created_at,
        expires_at: transaction.expires_at,
        settled_at: transaction.settled_at,
        fees_paid: transaction.fees_paid,
    })
}

/// List Lightning transactions
#[frb]
pub async fn strike_list_transactions(
    config: StrikeLightningConfig,
    params: ListTransactionsParams,
) -> Result<Vec<LightningTransaction>, ApiError> {
    let strike_config: StrikeConfig = config.into();
    let node = StrikeNode::new(strike_config);

    let lni_params = LniListTransactionsParams {
        from: params.from,
        limit: params.limit,
        payment_hash: None,
        search: params.search,
    };

    let transactions = node.list_transactions(lni_params).await.map_err(|e| {
        ApiError::LightningError(format!("Failed to list transactions: {}", e))
    })?;

    Ok(transactions
        .into_iter()
        .map(|t| LightningTransaction {
            type_: t.type_,
            invoice: t.invoice,
            payment_hash: t.payment_hash,
            amount_msats: t.amount_msats,
            description: t.description,
            created_at: t.created_at,
            expires_at: t.expires_at,
            settled_at: t.settled_at,
            fees_paid: t.fees_paid,
        })
        .collect())
}

/// Configuration for Nostr Wallet Connect
#[frb(non_opaque)]
#[derive(Debug, Clone)]
pub struct NostrWalletConnectConfig {
    /// NWC connection string (nostr+walletconnect://...)
    pub nwc_uri: String,
    /// Optional SOCKS5 proxy URL for Tor support
    pub socks5_proxy: Option<String>,
    /// Whether to accept invalid SSL certificates (for development)
    pub accept_invalid_certs: Option<bool>,
    /// HTTP timeout in seconds
    pub http_timeout: Option<i64>,
}

impl From<NostrWalletConnectConfig> for NwcConfig {
    fn from(config: NostrWalletConnectConfig) -> Self {
        NwcConfig {
            nwc_uri: config.nwc_uri,
            socks5_proxy: config.socks5_proxy,
            accept_invalid_certs: config.accept_invalid_certs,
            http_timeout: config.http_timeout,
        }
    }
}

/// Get NWC node information including balance
#[frb]
pub async fn nwc_get_info(config: NostrWalletConnectConfig) -> Result<LightningNodeInfo, ApiError> {
    let nwc_config: NwcConfig = config.into();
    let node = NwcNode::new(nwc_config);
    
    let info = node.get_info().await.map_err(|e| {
        ApiError::LightningError(format!("Failed to get NWC node info: {}", e))
    })?;

    Ok(LightningNodeInfo {
        alias: info.alias,
        public_key: info.pubkey,
        send_balance_msats: info.send_balance_msat,
        receive_balance_msats: info.receive_balance_msat,
    })
}

/// Create a Lightning invoice with NWC
#[frb]
pub async fn nwc_create_invoice(
    config: NostrWalletConnectConfig,
    params: CreateInvoiceParams,
) -> Result<LightningTransaction, ApiError> {
    let nwc_config: NwcConfig = config.into();
    let node = NwcNode::new(nwc_config);

    let lni_params = LniCreateInvoiceParams {
        invoice_type: InvoiceType::Bolt11,
        amount_msats: params.amount_msats,
        description: params.description,
        expiry: params.expiry,
        ..Default::default()
    };

    let transaction = node.create_invoice(lni_params).await.map_err(|e| {
        ApiError::LightningError(format!("Failed to create invoice: {}", e))
    })?;

    Ok(LightningTransaction {
        type_: transaction.type_,
        invoice: transaction.invoice,
        payment_hash: transaction.payment_hash,
        amount_msats: transaction.amount_msats,
        description: transaction.description,
        created_at: transaction.created_at,
        expires_at: transaction.expires_at,
        settled_at: transaction.settled_at,
        fees_paid: transaction.fees_paid,
    })
}

/// Pay a Lightning invoice with NWC
#[frb]
pub async fn nwc_pay_invoice(
    config: NostrWalletConnectConfig,
    params: PayInvoiceParams,
) -> Result<PayInvoiceResponse, ApiError> {
    let nwc_config: NwcConfig = config.into();
    let node = NwcNode::new(nwc_config);

    let lni_params = LniPayInvoiceParams {
        invoice: params.invoice,
        fee_limit_percentage: params.fee_limit_percentage,
        ..Default::default()
    };

    let response = node.pay_invoice(lni_params).await.map_err(|e| {
        ApiError::LightningError(format!("Failed to pay invoice: {}", e))
    })?;

    Ok(PayInvoiceResponse {
        payment_hash: response.payment_hash,
        preimage: response.preimage,
        fee_msats: response.fee_msats,
    })
}

/// Lookup a Lightning invoice by payment hash with NWC
#[frb]
pub async fn nwc_lookup_invoice(
    config: NostrWalletConnectConfig,
    payment_hash: String,
) -> Result<LightningTransaction, ApiError> {
    let nwc_config: NwcConfig = config.into();
    let node = NwcNode::new(nwc_config);

    let params = LookupInvoiceParams {
        payment_hash: Some(payment_hash),
        ..Default::default()
    };

    let transaction = node.lookup_invoice(params).await.map_err(|e| {
        ApiError::LightningError(format!("Failed to lookup invoice: {}", e))
    })?;

    Ok(LightningTransaction {
        type_: transaction.type_,
        invoice: transaction.invoice,
        payment_hash: transaction.payment_hash,
        amount_msats: transaction.amount_msats,
        description: transaction.description,
        created_at: transaction.created_at,
        expires_at: transaction.expires_at,
        settled_at: transaction.settled_at,
        fees_paid: transaction.fees_paid,
    })
}

/// List Lightning transactions with NWC
#[frb]
pub async fn nwc_list_transactions(
    config: NostrWalletConnectConfig,
    params: ListTransactionsParams,
) -> Result<Vec<LightningTransaction>, ApiError> {
    let nwc_config: NwcConfig = config.into();
    let node = NwcNode::new(nwc_config);

    let lni_params = LniListTransactionsParams {
        from: params.from,
        limit: params.limit,
        payment_hash: None,
        search: params.search,
    };

    let transactions = node.list_transactions(lni_params).await.map_err(|e| {
        ApiError::LightningError(format!("Failed to list transactions: {}", e))
    })?;

    Ok(transactions
        .into_iter()
        .map(|t| LightningTransaction {
            type_: t.type_,
            invoice: t.invoice,
            payment_hash: t.payment_hash,
            amount_msats: t.amount_msats,
            description: t.description,
            created_at: t.created_at,
            expires_at: t.expires_at,
            settled_at: t.settled_at,
            fees_paid: t.fees_paid,
        })
        .collect())
}

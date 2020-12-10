{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}

-- | Byron key types and their 'Key' class instances
--
module Cardano.Api.KeysByron (

    -- * Key types
    ByronKey,
    ByronKeyLegacy,

    -- * Data family instances
    AsType(..),
    VerificationKey(..),
    SigningKey(..),
    Hash(..),
  ) where

import           Prelude

import           Data.String (IsString)

import qualified Cardano.Crypto.DSIGN.Class as Crypto
import qualified Cardano.Crypto.Seed as Crypto
import qualified Cardano.Crypto.Wallet as Crypto.HD

import qualified Cardano.Chain.Common as Byron
import qualified Cardano.Crypto.Hashing as Byron
import qualified Cardano.Crypto.Signing as Byron

import           Cardano.Api.Hash
import           Cardano.Api.HasTypeProxy
import           Cardano.Api.Key
import           Cardano.Api.KeysShelley
import           Cardano.Api.SerialiseBech32
import           Cardano.Api.SerialiseCBOR
import           Cardano.Api.SerialiseRaw
import           Cardano.Api.SerialiseTextEnvelope


-- | Byron-era payment keys. Used for Byron addresses and witnessing
-- transactions that spend from these addresses.
--
-- These use Ed25519 but with a 32byte \"chaincode\" used in HD derivation.
-- The inclusion of the chaincode is a design mistake but one that cannot
-- be corrected for the Byron era. The Shelley era 'PaymentKey's do not include
-- a chaincode. It is safe to use a zero or random chaincode for new Byron keys.
--
-- This is a type level tag, used with other interfaces like 'Key'.
--
data ByronKey
-- | This type level tag refers to the Byron era in which
-- we were use the protocol prior to PBFT.
data ByronKeyLegacy

instance HasTypeProxy ByronKey where
    data AsType ByronKey = AsByronKey
    proxyToAsType _ = AsByronKey

instance HasTypeProxy ByronKeyLegacy where
    data AsType ByronKeyLegacy = AsByronKeyLegacy
    proxyToAsType _ = AsByronKeyLegacy

instance Key ByronKey where

    newtype VerificationKey ByronKey =
           ByronVerificationKey Byron.VerificationKey
      deriving stock (Eq)
      deriving (Show, IsString) via UsingRawBytesHex (VerificationKey ByronKey)
      deriving newtype (ToCBOR, FromCBOR)
      deriving anyclass SerialiseAsCBOR

    newtype SigningKey ByronKey =
           ByronSigningKey Byron.SigningKey
      deriving (Show, IsString) via UsingRawBytesHex (SigningKey ByronKey)
      deriving newtype (ToCBOR, FromCBOR)
      deriving anyclass SerialiseAsCBOR

    deterministicSigningKey :: AsType ByronKey -> Crypto.Seed -> SigningKey ByronKey
    deterministicSigningKey AsByronKey seed =
       ByronSigningKey (snd (Crypto.runMonadRandomWithSeed seed Byron.keyGen))

    deterministicSigningKeySeedSize :: AsType ByronKey -> Word
    deterministicSigningKeySeedSize AsByronKey = 32

    getVerificationKey :: SigningKey ByronKey -> VerificationKey ByronKey
    getVerificationKey (ByronSigningKey sk) =
      ByronVerificationKey (Byron.toVerification sk)

    verificationKeyHash :: VerificationKey ByronKey -> Hash ByronKey
    verificationKeyHash (ByronVerificationKey vkey) =
      ByronKeyHash (Byron.hashKey vkey)


-- Need to implement the HasTextEnvelope instances
instance Key ByronKeyLegacy where

    newtype VerificationKey ByronKeyLegacy =
           ByronVerificationKeyLegacy Byron.VerificationKey
      deriving stock (Eq)
      deriving (Show, IsString) via UsingRawBytesHex (VerificationKey ByronKey)
      deriving newtype (ToCBOR, FromCBOR)
      deriving anyclass SerialiseAsCBOR

    newtype SigningKey ByronKeyLegacy =
           ByronSigningKeyLegacy Byron.SigningKey
      deriving (Show, IsString) via UsingRawBytesHex (SigningKey ByronKey)
      deriving newtype (ToCBOR, FromCBOR)
      deriving anyclass SerialiseAsCBOR
    -- TODO: Probably don't want to generate more legacy keys
    deterministicSigningKey :: AsType ByronKeyLegacy -> Crypto.Seed -> SigningKey ByronKeyLegacy
    deterministicSigningKey AsByronKeyLegacy seed =
       ByronSigningKeyLegacy (snd (Crypto.runMonadRandomWithSeed seed Byron.keyGen))
    -- TODO: Double check
    deterministicSigningKeySeedSize :: AsType ByronKeyLegacy -> Word
    deterministicSigningKeySeedSize AsByronKeyLegacy = 32
    -- TODO: Double check
    getVerificationKey :: SigningKey ByronKeyLegacy -> VerificationKey ByronKeyLegacy
    getVerificationKey (ByronSigningKeyLegacy sk) =
      ByronVerificationKeyLegacy (Byron.toVerification sk)
    -- TODO: Double check
    verificationKeyHash :: VerificationKey ByronKeyLegacy -> Hash ByronKeyLegacy
    verificationKeyHash (ByronVerificationKeyLegacy vkey) =
      ByronKeyHashLegacy (Byron.hashKey vkey)

newtype instance Hash ByronKeyLegacy = ByronKeyHashLegacy Byron.KeyHash
  deriving (Eq, Ord)
  deriving (Show, IsString) via UsingRawBytesHex (Hash ByronKey)

instance SerialiseAsRawBytes (Hash ByronKeyLegacy) where
    serialiseToRawBytes (ByronKeyHashLegacy (Byron.KeyHash vkh)) =
      Byron.abstractHashToBytes vkh

    deserialiseFromRawBytes (AsHash AsByronKeyLegacy) bs =
      ByronKeyHashLegacy . Byron.KeyHash <$> Byron.abstractHashFromBytes bs

instance HasTextEnvelope (VerificationKey ByronKeyLegacy) where
    textEnvelopeType _ = "PaymentVerificationKeyByronLegacy_ed25519_bip32"

instance HasTextEnvelope (SigningKey ByronKeyLegacy) where
    textEnvelopeType _ = "PaymentSigningKeyByronLegacy_ed25519_bip32"

instance SerialiseAsRawBytes (VerificationKey ByronKey) where
    serialiseToRawBytes (ByronVerificationKey (Byron.VerificationKey xvk)) =
      Crypto.HD.unXPub xvk

    deserialiseFromRawBytes (AsVerificationKey AsByronKey) bs =
      either (const Nothing) (Just . ByronVerificationKey . Byron.VerificationKey)
             (Crypto.HD.xpub bs)

instance SerialiseAsRawBytes (SigningKey ByronKey) where
    serialiseToRawBytes (ByronSigningKey (Byron.SigningKey xsk)) =
      Crypto.HD.unXPrv xsk

    deserialiseFromRawBytes (AsSigningKey AsByronKey) bs =
      either (const Nothing) (Just . ByronSigningKey . Byron.SigningKey)
             (Crypto.HD.xprv bs)

-- TODO: This needs to use the legacy stuff in cardano-cli
instance SerialiseAsRawBytes (SigningKey ByronKeyLegacy) where
    serialiseToRawBytes (ByronSigningKeyLegacy (Byron.SigningKey xsk)) =
      Crypto.HD.unXPrv xsk

    deserialiseFromRawBytes (AsSigningKey AsByronKeyLegacy) bs =
      either (const Nothing) (Just . ByronSigningKeyLegacy . Byron.SigningKey)
             (Crypto.HD.xprv bs)

instance SerialiseAsBech32 (VerificationKey ByronKey) where
    bech32PrefixFor         _ =  "addr_xvk"
    bech32PrefixesPermitted _ = ["addr_xvk"]

instance SerialiseAsBech32 (SigningKey ByronKey) where
    bech32PrefixFor         _ =  "addr_xsk"
    bech32PrefixesPermitted _ = ["addr_xsk"]


newtype instance Hash ByronKey = ByronKeyHash Byron.KeyHash
  deriving (Eq, Ord)
  deriving (Show, IsString) via UsingRawBytesHex (Hash ByronKey)

instance SerialiseAsRawBytes (Hash ByronKey) where
    serialiseToRawBytes (ByronKeyHash (Byron.KeyHash vkh)) =
      Byron.abstractHashToBytes vkh

    deserialiseFromRawBytes (AsHash AsByronKey) bs =
      ByronKeyHash . Byron.KeyHash <$> Byron.abstractHashFromBytes bs

instance HasTextEnvelope (VerificationKey ByronKey) where
    textEnvelopeType _ = "PaymentVerificationKeyByron_ed25519_bip32"

instance HasTextEnvelope (SigningKey ByronKey) where
    textEnvelopeType _ = "PaymentSigningKeyByron_ed25519_bip32"

instance CastVerificationKeyRole ByronKey PaymentExtendedKey where
    castVerificationKey (ByronVerificationKey vk) =
        PaymentExtendedVerificationKey
          (Byron.unVerificationKey vk)

instance CastVerificationKeyRole ByronKey PaymentKey where
    castVerificationKey =
        (castVerificationKey :: VerificationKey PaymentExtendedKey
                             -> VerificationKey PaymentKey)
      . (castVerificationKey :: VerificationKey ByronKey
                             -> VerificationKey PaymentExtendedKey)


{-# LANGUAGE CPP               #-}
{-# LANGUAGE NamedFieldPuns    #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
module Tests.UnitTests (testTree) where

import qualified Data.ByteString.Lazy as LBS

import           Test.Tasty (TestTree, testGroup)
import           Test.Tasty.HUnit (Assertion, testCase, assertEqual, (@=?))

import qualified Tests.Reference.Implementation as RefImpl
import           Tests.Reference.TestVectors
import           Tests.Reference (termToJson, equalJson)
import           Tests.Term as Term (toRefTerm, serialise, deserialise)

#if !MIN_VERSION_base(4,8,0)
import           Control.Applicative
#endif


-------------------------------------------------------------------------------
-- Unit tests for test vector from CBOR spec RFC7049 Appendix A
--

unit_externalTestVector :: [ExternalTestCase] -> Assertion
unit_externalTestVector = mapM_ unit_externalTestCase

unit_externalTestCase :: ExternalTestCase -> Assertion
unit_externalTestCase ExternalTestCase {
                        encoded,
                        decoded = Left expectedJson
                      } = do
  let term       = deserialise encoded
      actualJson = termToJson (toRefTerm term)
      reencoded  = serialise term

  expectedJson `equalJson` actualJson
  encoded @=? reencoded

unit_externalTestCase ExternalTestCase {
                        encoded,
                        decoded = Right expectedDiagnostic
                      } = do
  let term             = deserialise encoded
      actualDiagnostic = RefImpl.diagnosticNotation (toRefTerm term)
      reencoded        = serialise term

  expectedDiagnostic @=? actualDiagnostic
  encoded @=? reencoded


-------------------------------------------------------------------------------
-- Unit tests for test vector from CBOR spec RFC7049 Appendix A
--

unit_expectedDiagnosticNotation :: RFC7049TestCase -> Assertion
unit_expectedDiagnosticNotation RFC7049TestCase {
                                  expectedDiagnostic,
                                  encodedBytes
                                } = do
  let term             = deserialise (LBS.pack encodedBytes)
      actualDiagnostic = RefImpl.diagnosticNotation (toRefTerm term)

  expectedDiagnostic @=? actualDiagnostic

-- | The reference implementation satisfies the roundtrip property for most
-- examples (all the ones from Appendix A). It does not satisfy the roundtrip
-- property in general however, non-canonical over-long int encodings for
-- example.
--
unit_encodedRoundtrip :: RFC7049TestCase -> Assertion
unit_encodedRoundtrip RFC7049TestCase {
                        expectedDiagnostic,
                        encodedBytes
                      } = do
  let term           = deserialise (LBS.pack encodedBytes)
      reencodedBytes = LBS.unpack (serialise term)

  assertEqual ("for CBOR: " ++ expectedDiagnostic) encodedBytes reencodedBytes


--------------------------------------------------------------------------------
-- TestTree API

testTree :: TestTree
testTree =
  testGroup "unit tests"
    [ testCase "RFC7049 test vector: decode" $
        mapM_ unit_expectedDiagnosticNotation rfc7049TestVector

    , testCase "RFC7049 test vector: roundtrip" $
        mapM_ unit_encodedRoundtrip rfc7049TestVector

    , withExternalTestVector $ \getTestVector ->
      testCase "external test vector" $
        getTestVector >>= unit_externalTestVector
    ]

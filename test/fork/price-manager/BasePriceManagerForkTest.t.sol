// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {PriceManager} from "src/PriceManager.sol";
import {FORK_BLOCK_2} from "test/Constants.t.sol";
import {BaseForkTest} from "test/fork/BaseForkTest.t.sol";

abstract contract BasePriceManagerForkTest is BaseForkTest(FORK_BLOCK_2) {
  /// @dev These reports are real Streams reports obtained from the mainnet Data Streams API
  /// See docs.chain.link/data-streams/tutorials/go-sdk-fetch
  PriceManager.ReportV3 internal s_linkReport;
  PriceManager.ReportV3 internal s_ethReport;
  PriceManager.ReportV3 internal s_usdcReport;
  bytes[] internal s_unverifiedReports;

  constructor() {
    bytes32[3] memory context = [
      bytes32(0x00094baebfda9b87680d8e59aa20a3e565126640ee7caeab3cd965e5568b17ee),
      bytes32(0x00000000000000000000000000000000000000000000000000000000011fcecf),
      bytes32(0x0000000000000000000000000000000000000000000000000000000400000001)
    ];

    bytes32[] memory rs = new bytes32[](6);
    bytes32[] memory ss = new bytes32[](6);
    bytes32 rawVs;

    // LINK Report
    s_linkReport = PriceManager.ReportV3({
      dataStreamsFeedId: LINK_USD_FEED_ID,
      validFromTimestamp: 1760166957,
      observationsTimestamp: 1760166957,
      nativeFee: 84842826185490,
      linkFee: 18047851399026195,
      expiresAt: 1762758957,
      price: 17730725215735380000,
      bid: 17725920000000000000,
      ask: 17734995767579328000
    });

    rs[0] = 0x50b61dc73f3b2c166411875a63db7a86db4c8c33048a5b038b4481b4b3b27929;
    rs[1] = 0x438688fc1672fe37988e3bcc7ea0052b5cd6cd92c0c2ddf7c0e7501dbd825bd3;
    rs[2] = 0x5e57de3e04f4892f9b6daba0fe1d3de84ee130576313a55f58bd93ef3576a203;
    rs[3] = 0x32cc6174d036a7f5423a813e7a0df4b998843bb66e3b52e77e1bd37b01c3750b;
    rs[4] = 0x9da90edd6b01b672a9730eb94807e5c718f067b02a15ba433f82e087f3a89d7b;
    rs[5] = 0x040a874e3fb804d1f0335d84ebcb5d6b31048711cbf5548ce06fd7e07ef44a83;

    ss[0] = 0x7afff19bc9974f2b568b93ee074f5e6464396162efe98c5b42f77121793be1ba;
    ss[1] = 0x72c147c59f30726806602c0483a3c742cfd7f4e22bb7a24a762d0d23d94df853;
    ss[2] = 0x555cb2385f84cc3be03f74396b97c3c6ad582bf13af0ba09ec761dee577b7044;
    ss[3] = 0x6a9211e380aa7df91c2b51d239656b09af5611d4d0025edcd412e136799bbe27;
    ss[4] = 0x0059c635caca0eb069abefa148f2f287b89c1f91bdf1066cde43261bc0807651;
    ss[5] = 0x20a581fcad6f7c002a32fd7cf8bbaea736a8754e4b39ede5252a769f4e0fd99a;

    rawVs = 0x0000010000010000000000000000000000000000000000000000000000000000;

    s_unverifiedReports.push(abi.encode(context, abi.encode(s_linkReport), rs, ss, rawVs));

    // ETH Report
    s_ethReport = PriceManager.ReportV3({
      dataStreamsFeedId: ETH_USD_FEED_ID,
      validFromTimestamp: 1760166957,
      observationsTimestamp: 1760166957,
      nativeFee: 84842826185490,
      linkFee: 18047851399026195,
      expiresAt: 1762758957,
      price: 3771680110000000000000,
      bid: 3771408069723518000000,
      ask: 3771881500000000000000
    });

    rs[0] = 0x3f3fdda0c0f140617878318c788274040876156231fd3cd616fe429c5f5867bc;
    rs[1] = 0x269a572f44266ab98bd66f75b3d40dc359f049cef54081ae6f6194130ed806f8;
    rs[2] = 0xe7daa5f519569bb93f5b43b82182840cf96e749b8206d8a97f86b53747e6d2c5;
    rs[3] = 0x7fe58105ad3954852bf9ff3432b5f971331bf349e9e123bfb2ead0729d801af1;
    rs[4] = 0x75807f8d9359a70afe7aa0fa9a304c3537dbf716cc3afecd015908ef3a86454d;
    rs[5] = 0x1362162e8760a829d4e619f447863ba0572f601f4af202eb57e4170d8ef86f4f;

    ss[0] = 0x0a5de65a8c511575ba605bb75b7cbeac01909b497486e6f772de8e31fdc76175;
    ss[1] = 0x0999d917bef9861fde7d3cbc5b0dd31a585537d8b7bd11e0b16db8f20192698c;
    ss[2] = 0x00062ed0bc2050622ebed0d3b96dc731286452a8ad00aff51c2caa788fafe8e5;
    ss[3] = 0x77ab84f30136483f5d1076fd07413a7b2d86a36d07b6b4cd73b6a0ad4a7b24de;
    ss[4] = 0x01ef1f36446c2aa276b04b5f695ee15f86e0b0ffe446cac886c29dbf962c80b4;
    ss[5] = 0x4555fff16414a3a7b6e9d35b0a4bea138acc2c22d569e8902820deb0955fcc7c;

    rawVs = 0x0000000101000000000000000000000000000000000000000000000000000000;

    s_unverifiedReports.push(abi.encode(context, abi.encode(s_ethReport), rs, ss, rawVs));

    // USDC Report
    s_usdcReport = PriceManager.ReportV3({
      dataStreamsFeedId: USDC_USD_FEED_ID,
      validFromTimestamp: 1760166957,
      observationsTimestamp: 1760166957,
      nativeFee: 84842826185490,
      linkFee: 18047851399026195,
      expiresAt: 1762758957,
      price: 999941200000000000,
      bid: 999830050000000000,
      ask: 1000052410000000000
    });

    rs[0] = 0xb70190b1ab017562688f7301041d340cfe8916ac4a9901d6c01b53d88712f32e;
    rs[1] = 0x02515e6d89a50f502496ae4e3196aaee76b885c5ee7eb8d7ebf971838699997d;
    rs[2] = 0xbb533a75477e667d3057c7edeb45b7701c13d53f0bfa5be10f4e3787b2c89464;
    rs[3] = 0xd4df258e875df46ba2ee3f83f6eb10e67a86b0547825338fd03bdfbbc4f98a5a;
    rs[4] = 0x05f08776080b07c5138f6f6edd0b35a1a3e46142cacf5f5d0bb3d45aad1c7c21;
    rs[5] = 0x9cde9875a6ca94c7abd670147fcba2c08b7146074c700afe636d65b739562aaa;

    ss[0] = 0x7b9142e8418adbe982ac28652dc16c998bf729f4a186b0844f0c99c10f5d9b39;
    ss[1] = 0x05a72f90185598eac80caccc2b0bde69a287a977cec43b95a1b3568ad346c13a;
    ss[2] = 0x115f7641675ed70ed9ce9541bd2e6b5aeecd48dfce80ce4a74bddfc74cd678b4;
    ss[3] = 0x15585e2e7088bf7d6d7f3607103d73ab73c1b2beed9e738a0cd6f8975a0d6f1e;
    ss[4] = 0x5097ef1abd0e1c5b386c60e0af984b542f3b635ae884e42ec99504b7660cdba9;
    ss[5] = 0x231a55746c4e4f9f08996d834e550302e6ec950c9b6cab522c2357acfd494c30;

    rawVs = 0x0100010000000000000000000000000000000000000000000000000000000000;

    s_unverifiedReports.push(abi.encode(context, abi.encode(s_usdcReport), rs, ss, rawVs));
  }
}

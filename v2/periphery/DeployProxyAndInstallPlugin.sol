// SPDX-License-Identifier: GPL-3-0-or-later
pragma solidity >=0.8.13;

import { IPRBProxy } from "@prb/proxy/interfaces/IPRBProxy.sol";
import { IPRBProxyRegistry } from "@prb/proxy/interfaces/IPRBProxyRegistry.sol";
import { ISablierV2ProxyPlugin } from "@sablier/v2-periphery/interfaces/ISablierV2ProxyPlugin.sol";

/// @notice Example of how to deploy a Proxy and install the Sablier plugin.
/// @dev This code is referenced in the docs:
/// https://docs.sablier.com/contracts/v2/guides/proxy-architecture/deployandinstallplugin
contract ProxyDeployerAndPluginInstaller {
    IPRBProxyRegistry public constant PROXY_REGISTRY = IPRBProxyRegistry(0xD42a2bB59775694c9Df4c7822BfFAb150e6c699D);
    ISablierV2ProxyPlugin public immutable sablierProxyPlugin;

    constructor(ISablierV2ProxyPlugin sablierProxyPlugin_) {
        sablierProxyPlugin = sablierProxyPlugin_;
    }

    function deployProxyAndInstallPlugin() public returns (IPRBProxy proxy) {
        // Get the proxy for this contract
        proxy = PROXY_REGISTRY.getProxy({ owner: address(this) });
        if (address(proxy) == address(0)) {
            // Deploy the proxy if it doesn't exist and install the plugin
            proxy = PROXY_REGISTRY.deployAndInstallPlugin({ plugin: sablierProxyPlugin });
        } else {
            // If it exists then just install the plugin
            PROXY_REGISTRY.installPlugin({ plugin: sablierProxyPlugin });
        }
    }
}

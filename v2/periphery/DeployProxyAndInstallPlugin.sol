// SPDX-License-Identifier: GPL-3-0-or-later
pragma solidity >=0.8.13;

import { IPRBProxy } from "@prb/proxy/interfaces/IPRBProxy.sol";
import { IPRBProxyRegistry } from "@prb/proxy/interfaces/IPRBProxyRegistry.sol";
import { ISablierV2ProxyPlugin } from "@sablier/v2-periphery/interfaces/ISablierV2ProxyPlugin.sol";

contract DeployProxyAndInstallPlugin {
    IPRBProxyRegistry public constant PROXY_REGISTRY = IPRBProxyRegistry(0x33e200B5fb5e0C57d370d5202c26A35d07A46B98);
    ISablierV2ProxyPlugin public immutable sablierProxyPlugin;

    constructor(ISablierV2ProxyPlugin sablierProxyPlugin_) {
        sablierProxyPlugin = sablierProxyPlugin_;
    }

    function deployProxyAndInstallPlugin() public returns (IPRBProxy proxy) {
        proxy = PROXY_REGISTRY.getProxy({ owner: address(this) }); // Get the proxy for this contract
        if (address(proxy) == address(0)) {
            proxy = PROXY_REGISTRY.deployAndInstallPlugin({ plugin: sablierProxyPlugin }); // Deploy the proxy if it
                // doesn't exist and install the plugin
        } else {
            PROXY_REGISTRY.installPlugin({ plugin: sablierProxyPlugin });
        }
    }
}

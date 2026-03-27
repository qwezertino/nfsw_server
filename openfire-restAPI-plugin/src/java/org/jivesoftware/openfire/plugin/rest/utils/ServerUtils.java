package org.jivesoftware.openfire.plugin.rest.utils;

import org.jivesoftware.openfire.XMPPServer;
import org.xmpp.packet.JID;

public class ServerUtils {
    public static JID getServerAddress() {
        return getFullJid("sbrw.engine.engine", "EA_Chat");
    }

    public static JID getFullJid(String userName, String resource) {
        return new JID(userName, XMPPServer.getInstance().getServerInfo().getXMPPDomain(), resource);
    }
}

INSERT INTO ofProperty (name, propValue) VALUES ('xmpp.domain',             '${SERVER_IP}')      ON DUPLICATE KEY UPDATE propValue = VALUES(propValue);
INSERT INTO ofProperty (name, propValue) VALUES ('xmpp.fqdn',               '${SERVER_IP}')      ON DUPLICATE KEY UPDATE propValue = VALUES(propValue);
INSERT INTO ofProperty (name, propValue) VALUES ('plugin.restapi.enabled',   'true')              ON DUPLICATE KEY UPDATE propValue = VALUES(propValue);
INSERT INTO ofProperty (name, propValue) VALUES ('plugin.restapi.secret',    '${OPENFIRE_TOKEN}') ON DUPLICATE KEY UPDATE propValue = VALUES(propValue);
INSERT INTO ofProperty (name, propValue) VALUES ('xmpp.auth.iqauth',         'true')              ON DUPLICATE KEY UPDATE propValue = VALUES(propValue);
INSERT INTO ofProperty (name, propValue) VALUES ('stream.management.active', 'false')             ON DUPLICATE KEY UPDATE propValue = VALUES(propValue);
INSERT INTO ofProperty (name, propValue) VALUES ('xmpp.audit.active',        'false')             ON DUPLICATE KEY UPDATE propValue = VALUES(propValue);
INSERT INTO ofProperty (name, propValue) VALUES ('adminConsole.access.allow-wildcards-in-excludes', 'true') ON DUPLICATE KEY UPDATE propValue = VALUES(propValue);

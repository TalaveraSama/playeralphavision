"""Configure public TLS SPKI pins; never a server password or private key.
Run BEFORE compiling, using two real independent public keys maintained by the operator.
"""
import argparse
from copy import deepcopy
import base64
from datetime import date, timedelta
from pathlib import Path
import re
import xml.etree.ElementTree as ET


def configure(domain, primary, backup, expires):
    if not re.fullmatch(r'[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?', domain):
        raise ValueError('Use only the panel hostname, without scheme, port or path')
    if primary == backup:
        raise ValueError('Current and backup pins must be distinct independent public keys')
    for pin in (primary, backup):
        if len(base64.b64decode(pin, validate=True)) != 32:
            raise ValueError('Each pin must encode a SHA-256 digest (32 bytes)')
    expiration = date.fromisoformat(expires)
    if not date.today() < expiration <= date.today() + timedelta(days=365):
        raise ValueError('Expiration must be in the future and within 365 days')
    root = ET.Element('network-security-config')
    base = ET.SubElement(root, 'base-config', cleartextTrafficPermitted='true')
    ET.SubElement(ET.SubElement(base, 'trust-anchors'), 'certificates', src='system')
    config = ET.SubElement(root, 'domain-config', cleartextTrafficPermitted='false')
    ET.SubElement(config, 'domain', includeSubdomains='false').text = domain.lower()
    pins = ET.SubElement(config, 'pin-set', expiration=expires)
    for pin in (primary, backup):
        ET.SubElement(pins, 'pin', digest='SHA-256').text = pin
    ET.indent(root)
    return ET.tostring(root, encoding='unicode', xml_declaration=True) + '\n'


def preserve_other_domains(generated, previous, changed_domain):
    """Rotating panel pins must not remove the video's HTTPS-only policy."""
    root = ET.fromstring(generated)
    existing = ET.fromstring(previous)
    for config in existing.findall('domain-config'):
        clone = deepcopy(config)
        for domain in list(clone.findall('domain')):
            if (domain.text or '').strip().lower() == changed_domain.lower():
                clone.remove(domain)
        if clone.findall('domain'):
            root.append(clone)
    ET.indent(root)
    return ET.tostring(root, encoding='unicode', xml_declaration=True) + '\n'


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for arg in ('domain', 'primary', 'backup', 'expires'):
        parser.add_argument('--' + arg, required=True)
    args = parser.parse_args()
    text = configure(args.domain, args.primary, args.backup, args.expires)
    path = Path(__file__).resolve().parents[1] / 'android/app/src/main/res/xml/network_security_config.xml'
    if path.exists():
        text = preserve_other_domains(text, path.read_text(), args.domain)
    path.write_text(text)
    print('Public pins configured. Verify both keys and TLS connections on Android before distributing.')

base = BaseOrtn();
encoded = base.encode_str("aodnaend");
base.play_sound(encoded);
decoded = base.decode_to_bytes(encoded);

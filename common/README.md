# MODULES

## SerDes

User interface of the whole proyect. Provides I-O for different formats (str, etc). Encodes and decodes the messages, applying error correctiona and such in the way

When instaciated, it must be supplied with the base instance it will use to process the signals. If not provided with any base, it defaults to `NoneBase`, an empty placeholder base that shouldnt be used
The validity of a base can be automatically testes with `SerDes.auto_test_base(base_instance)`

## Bases

The abstract class `AbstBase` defines the interface that creates, operate and provides the methods to interact with a otronormal base of a vectorial space. 

For example, `BasesSines.m` implements this behaviour with sinusuidal bases
In the `configs/base_sines.json` several parameters such as the bandwidth, the dimension of the vectorial space (length of thw word), and other parameters can be configured

### Bases Abstract Methods / Parameters

Every Base class must have the following abstract parameters:
- `n_of_bases`: Numbers of vectors in the base. Other way to see it is as the number of symbols a word will carry
- `word_duration_t`: The duration in seconds of a single word 
- `sampling_frec`: Sampling frecuency at which the base produces / recieves signals

Every Base class must implement:
- `to_signal(word) -> signal`: Transfroms a word into a singal
- `from_signal(signal) -> word`: Transfroms a signal into a word

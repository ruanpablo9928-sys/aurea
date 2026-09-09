/// A VERSAO QUE O APLICATIVO DIZ TER.
///
/// Ela estava escrita a mao na tela Sobre e parou em `1.2.0 (35)` — 32
/// entregas atras. Isso nao e cosmetico: quando alguem manda um registro
/// de travada, a primeira pergunta e "de qual build?", e a tela que devia
/// responder respondia errado. Uma rodada inteira de diagnostico se
/// perdeu nisso.
///
/// Agora e uma constante so, e `test/versao_bate_com_pubspec_test.dart`
/// falha se ela sair de sincronia com o `pubspec.yaml`. Esquecer de
/// atualizar deixou de ser possivel em silencio.
const versaoDoApp = '1.6.9';

/// O numero da compilacao — o que muda a cada IPA/APK entregue.
const buildDoApp = 70;

/// Como aparece para quem le: `1.6.7 (68)`.
const versaoCompleta = '$versaoDoApp ($buildDoApp)';

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import org.bouncycastle.asn1.x509.GeneralName;
import org.bouncycastle.asn1.x509.GeneralSubtree;
import org.bouncycastle.asn1.x509.PKIXNameConstraintValidator;
import org.bouncycastle.asn1.x509.NameConstraintValidatorException;
import org.bouncycastle.crypto.engines.GOST28147Engine;
import org.bouncycastle.crypto.modes.G3413CTRBlockCipher;
import org.bouncycastle.crypto.params.KeyParameter;
import org.bouncycastle.crypto.params.ParametersWithIV;
import org.jdom2.Document;
import org.jdom2.input.SAXBuilder;

// One-off condition fixtures. No application, signing, network or cache access.
public final class AdvisoryConditions {
  private static boolean rejected(int type, String name) {
    PKIXNameConstraintValidator validator = new PKIXNameConstraintValidator();
    validator.addExcludedSubtree(new GeneralSubtree(new GeneralName(type, "blocked.invalid")));
    try {
      validator.checkExcluded(new GeneralName(type, name));
      return false;
    } catch (NameConstraintValidatorException expected) {
      return true;
    }
  }

  private static void crypto() {
    G3413CTRBlockCipher cipher = new G3413CTRBlockCipher(new GOST28147Engine());
    int block = cipher.getBlockSize();
    cipher.init(true, new ParametersWithIV(new KeyParameter(new byte[32]), new byte[block / 2]));
    byte[] in = new byte[block * 257];
    byte[] out = new byte[in.length];
    cipher.processBytes(in, 0, in.length, out, 0);
    boolean repeated = Arrays.equals(Arrays.copyOfRange(out, 0, block),
        Arrays.copyOfRange(out, block * 256, block * 257));
    System.out.println("gost_blocks_0_256_equal=" + repeated);
    System.out.println("email_plain_rejected=" + rejected(GeneralName.rfc822Name, "mobi@blocked.invalid"));
    System.out.println("email_trailing_dot_rejected=" + rejected(GeneralName.rfc822Name, "mobi@blocked.invalid."));
    System.out.println("uri_plain_rejected=" + rejected(GeneralName.uniformResourceIdentifier, "https://blocked.invalid/"));
    System.out.println("uri_trailing_dot_rejected=" + rejected(GeneralName.uniformResourceIdentifier, "https://blocked.invalid./"));
  }

  private static void xml(Path ownedDirectory) throws Exception {
    // The only referenced resource is this freshly created, known-content file.
    Path canary = ownedDirectory.resolve("owned-canary.txt");
    String token = "MOBI_OWNED_XML_CANARY";
    Files.writeString(canary, token);
    String text = "<!DOCTYPE root [<!ENTITY owned SYSTEM '" + canary.toUri() + "'>]>"
        + "<root>&owned;</root>";
    byte[] bytes = text.getBytes(StandardCharsets.UTF_8);
    SAXBuilder defaults = new SAXBuilder();
    Document defaultResult = defaults.build(new ByteArrayInputStream(bytes));
    SAXBuilder hardened = new SAXBuilder();
    hardened.setExpandEntities(false);
    Document hardResult = hardened.build(new ByteArrayInputStream(bytes));
    // Invoke the actual selected Jetifier helper; do not substitute its implementation.
    Class<?> helper = Class.forName("com.android.tools.build.jetifier.processor.transform.pom.XmlUtils");
    Object companion = helper.getField("Companion").get(null);
    Document jetifier = (Document) companion.getClass()
        .getMethod("createDocumentFromByteArray", byte[].class).invoke(companion, (Object) bytes);
    System.out.println("jdom_default_canary_expanded=" + defaultResult.getRootElement().getText().contains(token));
    System.out.println("jdom_expand_false_canary_expanded=" + hardResult.getRootElement().getText().contains(token));
    System.out.println("jetifier_helper_canary_expanded=" + jetifier.getRootElement().getText().contains(token));
    Files.delete(canary);
  }

  public static void main(String[] args) throws Exception {
    if (args.length == 1 && args[0].equals("crypto")) crypto();
    else if (args.length == 2 && args[0].equals("xml")) xml(Path.of(args[1]));
    else throw new IllegalArgumentException("Expected crypto or xml OWNED_DIRECTORY");
  }
}

public class NoCsrfInSpringTest1 {
    @Override
    protected void configure(HttpSecurity http) throws Exception {
        // type: P, target-rule-id: no-csrf-protection-explicit-in-spring-java, target-engine: semgrep
        http.csrf().disable().authorizeRequests().antMatchers("/home").permitAll().authenticated();
    }
}

public class NoCsrfInSpringTest2 {
    protected void configure(HttpSecurity http) throws Exception {
        // type: N, target-rule-id: no-csrf-protection-explicit-in-spring-java, target-engine: semgrep 
        http.authorizeRequests().antMatchers("/home").permitAll().authenticated();
    }
}

public class InsecureBlowfishCipherInJavaxCrypto {
    public static void main(String[] args) throws Exception {
        String key = "foo";
        String data = "bar";

        SecretKeySpec secretKey = new SecretKeySpec(key.getBytes(), "Blowfish");

        // type: P, target-rule-id: insecure-blowfish-cipher-in-javax-crypto-java, target-engine: semgrep
        Cipher cipher = Cipher.getInstance("Blowfish");

        // type: N, target-rule-id: insecure-blowfish-cipher-in-javax-crypto-java, target-engine: semgrep
        Cipher cipher = Cipher.getInstance("AES/CBC/PKCS5Paddin");
    }
}


public class EntityExpansionInXmlSteam {

    public void test1(InputStream input) throws XMLStreamException {
        XMLInputFactory factory = XMLInputFactory.newFactory();
        // type: P, target-rule-id: external-entity-reference-in-xml-stream-java, target-engine: semgrep 
        XMLStreamReader reader = factory.createXMLStreamReader(input);
    }

    public void test2(InputStream input) throws XMLStreamException {
        XMLInputFactory factory = XMLInputFactory.newFactory();
        factory.setProperty(XMLInputFactory.IS_SUPPORTING_EXTERNAL_ENTITIES, true);
        // type: P, target-rule-id: external-entity-reference-in-xml-stream-java, target-engine: semgrep 
        XMLStreamReader reader = factory.createXMLStreamReader(input);
    }

    public void test3(InputStream input) throws XMLStreamException {
        XMLInputFactory factory = XMLInputFactory.newFactory();
        factory.setProperty(XMLInputFactory.IS_SUPPORTING_EXTERNAL_ENTITIES, false);
        // type: N, target-rule-id: external-entity-reference-in-xml-stream-java, target-engine: semgrep 
        XMLStreamReader reader = factory.createXMLStreamReader(input);
    }

    public void test4(InputStream input) throws XMLStreamException {
        XMLInputFactory factory = XMLInputFactory.newFactory();
        factory.setProperty(XMLInputFactory.IS_SUPPORTING_EXTERNAL_ENTITIES, false);
        factory.setProperty(XMLInputFactory.SUPPORT_DTD, false);
        // type: N, target-rule-id: external-entity-reference-in-xml-stream-java, target-engine: semgrep 
        XMLStreamReader reader = factory.createXMLStreamReader(input);
    }

    public void test5(InputStream input) throws XMLStreamException {
        XMLInputFactory factory = XMLInputFactory.newFactory();
        factory.setProperty(XMLInputFactory.IS_SUPPORTING_EXTERNAL_ENTITIES, "foo");
        // type: P, target-rule-id: external-entity-reference-in-xml-stream-java, target-engine: semgrep 
        XMLStreamReader reader = factory.createXMLStreamReader(input);
    }
}
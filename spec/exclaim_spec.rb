# frozen_string_literal: true

describe Exclaim do
  it "has a version number" do
    expect(Exclaim::VERSION).not_to be nil
  end

  describe ".element_name" do
    it "determines a component name with an explicit $component" do
      expect(Exclaim.element_name({ '$component' => 'text' })).to eq('text')
    end

    it "determines a helper name with an explicit $helper" do
      expect(Exclaim.element_name({ '$helper' => 'join' })).to eq('join')
    end

    it "returns 'bind' for a $bind reference" do
      expect(Exclaim.element_name({ '$bind' => 'bind' })).to eq('bind')
    end

    it "for shorthand declarations it returns the name with the leading $ removed" do
      expect(Exclaim.element_name({ '$text' => 'some value' })).to eq('text')
      expect(Exclaim.element_name({ '$join' => [1, 2, 3], 'separator' => ',' })).to eq('join')
    end

    it "returns nil if the given Hash has no Exclaim-style element declaration" do
      expect(Exclaim.element_name({ 'not' => 'exclaim reference' })).to eq(nil)
    end

    it "returns nil and logs a warning when given a non-Hash value" do
      allow(Exclaim.logger).to receive(:warn)

      expect(Exclaim.element_name('$text')).to eq(nil)
      warning = 'Exclaim.element_name can only determine name from a Hash, given String value'
      expect(Exclaim.logger).to have_received(:warn).with(warning)
    end
  end
end

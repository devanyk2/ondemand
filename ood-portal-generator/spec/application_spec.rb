require 'spec_helper'
require File.expand_path '../../lib/ood_portal_generator', __FILE__
require 'tempfile'

describe OodPortalGenerator::Application do
  let(:argv) do
    %W()
  end

  let(:sum) do
    Tempfile.new('sum')
  end

  let(:apache) do
    Tempfile.new('apache')
  end

  let(:apache_bak) do
    Tempfile.new('apache_bak')
  end

  before(:each) do
    stub_const('ARGV', argv)
    allow(described_class).to receive(:sum).and_return(sum.path)
  end

  after(:each) do
    sum.unlink
    apache.unlink
  end

  describe 'generate' do
    it 'runs generate' do
      expect { described_class.start('generate') }.to output(/VirtualHost/).to_stdout
    end
  end

  describe 'save_checksum' do
    it 'saves checksum file' do
      allow(File).to receive(:readlines).with('/dne.conf').and_return(["# comment\n", "foo\n", "  #comment\n"])
      described_class.save_checksum('/dne.conf')
      expect(File.read(sum.path)).to eq("b5bb9d8014a0f9b1d61e21e796d78dccdf1352f23cd32812f4850b878ae4944c /opt/rh/httpd24/root/etc/httpd/conf.d/ood-portal.conf\n")
    end
  end

  describe 'checksum_matches?' do
    it 'matches' do
      allow(File).to receive(:readlines).with(sum.path).and_return(["b5bb9d8014a0f9b1d61e21e796d78dccdf1352f23cd32812f4850b878ae4944c /opt/rh/httpd24/root/etc/httpd/conf.d/ood-portal.conf\n"])
      allow(File).to receive(:readlines).with('/dne.conf').and_return(["# comment\n", "foo\n", "  #comment\n"])
      expect(described_class.checksum_matches?('/dne.conf')).to eq(true)
    end

    it 'does not match' do
      allow(File).to receive(:readlines).with(sum.path).and_return(["b5bb9d8014a0f9b1d61e21e796d78dccdf1352f23cd32812f4850b878ae4944c /opt/rh/httpd24/root/etc/httpd/conf.d/ood-portal.conf\n"])
      allow(File).to receive(:readlines).with('/dne.conf').and_return(["# comment\n", "bar\n", "  #comment\n"])
      expect(described_class.checksum_matches?('/dne.conf')).to eq(false)
    end
  end

  describe 'checksum_exists?' do
    it 'returns true' do
      allow(File).to receive(:readlines).with(sum.path).and_return(["b5bb9d8014a0f9b1d61e21e796d78dccdf1352f23cd32812f4850b878ae4944c /opt/rh/httpd24/root/etc/httpd/conf.d/ood-portal.conf\n"])
      expect(described_class.checksum_exists?).to eq(true)
    end

    it 'returns false' do
      allow(File).to receive(:readlines).with(sum.path).and_return(["b5bb9d8014a0f9b1d61e21e796d78dccdf1352f23cd32812f4850b878ae4944c /foo/bar\n"])
      expect(described_class.checksum_exists?).to eq(true)
    end

    it 'returns false if checksum does not exist' do
      allow(File).to receive(:readlines).with(sum.path).and_return(nil)
      sum.unlink
      expect(described_class.checksum_exists?).to eq(false)
    end
  end

  describe 'update_ood_portal' do
    it 'does not replace if no changes detected' do
      allow(described_class).to receive(:checksum_exists?).and_return(true)
      allow(described_class).to receive(:update_replace?).and_return(false)
      allow(FileUtils).to receive(:cmp).and_return(true)
      ret = described_class.update_ood_portal()
      expect(ret).to eq(0)
    end

    it 'does not replace if checksums do not match and cmp is true' do
      allow(described_class).to receive(:detailed_exitcodes).and_return(true)
      allow(described_class).to receive(:apache).and_return(apache.path)
      allow(described_class).to receive(:checksum_exists?).and_return(true)
      allow(described_class).to receive(:update_replace?).and_return(true)
      allow(FileUtils).to receive(:cmp).and_return(true)
      ret = described_class.update_ood_portal()
      expect(ret).to eq(0)
    end

    it 'does replace if checksums match and cmp is false' do
      allow(described_class).to receive(:detailed_exitcodes).and_return(true)
      allow(described_class).to receive(:apache).and_return(apache.path)
      allow(described_class).to receive(:checksum_exists?).and_return(true)
      allow(described_class).to receive(:update_replace?).and_return(true)
      allow(FileUtils).to receive(:cmp).and_return(false)
      expect(described_class).to receive(:save_checksum).with(apache.path)
      ret = described_class.update_ood_portal()
      expect(ret).to eq(3)
    end

    it 'creates backup of Apache when replacing' do
      allow(described_class).to receive(:detailed_exitcodes).and_return(true)
      allow(described_class).to receive(:apache).and_return(apache.path)
      allow(described_class).to receive(:apache_bak).and_return("#{apache.path}.bak")
      allow(described_class).to receive(:checksum_exists?).and_return(true)
      allow(described_class).to receive(:update_replace?).and_return(true)
      allow(FileUtils).to receive(:cmp).and_return(false)
      expect(described_class).to receive(:save_checksum).with(apache.path)
      ret = described_class.update_ood_portal()
      expect(ret).to eq(3)
      expect(File.exist?("#{apache.path}.bak")).to eq(true)
    end

    it 'does not replace if checksums do not match and cmp is false' do
      allow(described_class).to receive(:detailed_exitcodes).and_return(true)
      allow(described_class).to receive(:apache).and_return(apache.path)
      allow(described_class).to receive(:checksum_exists?).and_return(true)
      allow(described_class).to receive(:update_replace?).and_return(false)
      allow(FileUtils).to receive(:cmp).and_return(false)
      ret = described_class.update_ood_portal()
      expect(ret).to eq(4)
      expect(File.exist?("#{apache.path}.new")).to eq(true)
    end
  end
end

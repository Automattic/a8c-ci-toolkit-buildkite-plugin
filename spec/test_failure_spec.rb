require_relative '../lib/test_failure'
require 'rexml/document'

describe TestFailure do
  let(:node_xml) do
    <<-XML
      <testcase classname='WordPressTest.MediaServiceTests' name='testDeletingLocalMediaThatDoesntExistInCoreData'>
        <failure message='Asynchronous wait failed: Exceeded timeout of 0.1 seconds, with unfulfilled expectations: &quot;The delete call succeeds even if the media object isn&apos;t saved.&quot;.'>&lt;unknown&gt;:0</failure>
      </testcase>
    XML
  end

  let(:document) { REXML::Document.new(node_xml) }
  let(:node) { document.root }

  subject { TestFailure.new(node) }

  it 'initializes the TestFailure object correctly' do
    expect(subject.classname).to eq('WordPressTest.MediaServiceTests')
    expect(subject.name).to eq('testDeletingLocalMediaThatDoesntExistInCoreData')
    expect(subject.message).to eq('Asynchronous wait failed: Exceeded timeout of 0.1 seconds, with unfulfilled expectations: "The delete call succeeds even if the media object isn\'t saved.".')
    expect(subject.details).to eq('<unknown>:0')
    expect(subject.count).to eq(1)
  end
end

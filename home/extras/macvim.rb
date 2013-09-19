# -*- encoding : utf-8 -*-
require 'formula'

# Reference: https://github.com/b4winckler/macvim/wiki/building
class Macvim < Formula
  homepage 'http://code.google.com/p/macvim/'
  url 'https://github.com/b4winckler/macvim/archive/snapshot-70.tar.gz'
  version '7.4-70'
  sha1 '66432ae0fe81b2787b23343b6c99ef81f6b52c3e'

  head 'https://github.com/b4winckler/macvim.git', :branch => 'master'

  option "custom-icons", "Try to generate custom document icons"
  option "override-system-vim", "Override system vim"

  depends_on :xcode
  depends_on 'cscope' => :recommended
  depends_on 'lua' => :optional
  depends_on :python => :recommended
  # Help us! :python3 in MacVim makes the window disappear, so only 2.x bindings!

  def install

    3.times { opoo "INSTALL WITH brew install macvim --env=std" }

    # Set ARCHFLAGS so the Python app (with C extension) that is
    # used to create the custom icons will not try to compile in
    # PPC support (which isn't needed in Homebrew-supported systems.)
    ENV['ARCHFLAGS'] = "-arch #{MacOS.preferred_arch}"

    if MacOS.version == :snow_leopard && !File.exists?("/Developer/Library/Xcode/Plug-ins/GCC 4.2.xcplugin/Contents/Resources/cc")
      # Needed to build under OSX 1.6
      `mkdir -p /Developer/Library/Xcode/Plug-ins/GCC\\ 4.2.xcplugin/Contents/Resources/`
      `ln -s /usr/bin/cc /Developer/Library/Xcode/Plug-ins/GCC\\ 4.2.xcplugin/Contents/Resources/cc`
    end

    # If building for 10.7 or up, make sure that CC is set to "clang".
    ENV.clang if MacOS.version >= :lion

    # ruby version active
    ruby_path = `which -a ruby | grep "/ruby" | head -n1`

    python_version=`python -c "import sys; print sys.version"`.match(/^(.*?) /)[1]
    python_version_minor = python_version.match(/([2-3]\.[0-9]+)/)[1]
    python_path="/usr/local/Cellar/python/#{python_version}/Frameworks/Python.framework/Versions/Current/lib/python#{python_version_minor}/config"
    if !File.exists?("/usr/local/lib/python#{python_version_minor}/config") && File.exists?(python_path)
      ln_s(python_path, "/usr/local/lib/python#{python_version_minor}/config")
    end

    args = %W[
      --with-features=huge
      --enable-multibyte
      --with-macarchs=#{MacOS.preferred_arch}
      --enable-perlinterp
      --enable-rubyinterp
      --with-ruby-command=#{ruby_path}
      --with-tlib=ncurses
      --with-compiledby=Homebrew
      --with-local-dir=#{HOMEBREW_PREFIX}
    ]

    args << "--with-macsdk=#{MacOS.version}" unless MacOS::CLT.installed?
    args << "--enable-cscope" if build.with? "cscope"

    if build.with? "lua"
      args << "--enable-luainterp"
      args << "--with-lua-prefix=#{HOMEBREW_PREFIX}"
    end

    args << "--enable-pythoninterp=yes" if build.with? 'python'

    # MacVim seems to link Python by `-framework Python` (instead of
    # `python-config --ldflags`) and so we have to pass the -F to point to
    # where the Python.framework is located, we want it to use!
    # Also the -L is needed for the correct linking. This is a mess but we have
    # to wait until MacVim is really able to link against different Python's
    # on the Mac. Note configure detects brewed python correctly, but that
    # is ignored.
    # See https://github.com/mxcl/homebrew/issues/17908
    ENV.prepend 'LDFLAGS', "-L#{python2.libdir} -F#{python2.framework}" if python && python.brewed?

    unless MacOS::CLT.installed?
      # On Xcode-only systems:
      # Macvim cannot deal with "/Applications/Xcode.app/Contents/Developer" as
      # it is returned by `xcode-select -print-path` and already set by
      # Homebrew (in superenv). Instead Macvim needs the deeper dir to directly
      # append "SDKs/...".
      args << "--with-developer-dir=#{MacOS::Xcode.prefix}/Platforms/MacOSX.platform/Developer/"
    end

    system "./configure", *args

    if build.include? "custom-icons"
      # Get the custom font used by the icons
      cd 'src/MacVim/icons' do
        system "make getenvy"
      end
    else
      # Building custom icons fails for many users, so off by default.
      inreplace "src/MacVim/icons/Makefile", "$(MAKE) -C makeicns", ""
      inreplace "src/MacVim/icons/make_icons.py", "dont_create = False", "dont_create = True"
    end

    system "make"

    prefix.install "src/MacVim/build/Release/MacVim.app"
    inreplace "src/MacVim/mvim", /^# VIM_APP_DIR=\/Applications$/,
                                 "VIM_APP_DIR=#{prefix}"
    bin.install "src/MacVim/mvim"

    # Create MacVim vimdiff, view, ex equivalents
    executables = %w[mvimdiff mview mvimex gvim gvimdiff gview gvimex]
    executables += %w[vi vim vimdiff view vimex] if build.include? "override-system-vim"
    executables.each {|f| ln_s bin+'mvim', bin+f}
  end

  def caveats; <<-EOS.undent
    MacVim.app installed to:
      #{prefix}

    To link the application to a normal Mac OS X location:
        brew linkapps
    or:
        ln -s #{prefix}/MacVim.app /Applications
    EOS
  end
end
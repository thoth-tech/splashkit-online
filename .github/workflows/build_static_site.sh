set -e
#build_static_site.sh <sha> <workflow event_name> <username/repo>

# Do we need to build?
cd ./sko
# only build if the SplashKitWasm folder has changed, or if this was a push to a branch (so branches always build)
if ! git diff --quiet $(git merge-base "origin/main" "$1").."$1" -- SplashKitWasm &>/dev/null || [ "$2" == "push" ]; then
    cd ../

    echo "========================================"
    echo "Downloading Compilation Pre-builts (To improve...these should be buildable too)"
    echo "========================================"
    mkdir -p ./sko/SplashKitWasm/prebuilt/cxx/compiler/
    cd ./sko/SplashKitWasm/prebuilt/cxx/compiler/
    wget -O clang++.js https://raw.githubusercontent.com/WhyPenguins/SplashkitOnline/github-live/Browser_IDE/compilers/cxx/bin/clang++.js
    wget -O clang.wasm.lzma https://raw.githubusercontent.com/WhyPenguins/SplashkitOnline/github-live/Browser_IDE/compilers/cxx/bin/clang.wasm.lzma
    wget -O wasm-ld.js https://raw.githubusercontent.com/WhyPenguins/SplashkitOnline/github-live/Browser_IDE/compilers/cxx/bin/wasm-ld.js
    wget -O lld.wasm.lzma https://raw.githubusercontent.com/WhyPenguins/SplashkitOnline/github-live/Browser_IDE/compilers/cxx/bin/lld.wasm.lzma
    wget -O sysroot.zip https://github.com/WhyPenguins/SplashkitOnline/raw/refs/heads/cxx_language_backend_binaries/SplashKitWasm/prebuilt/sysroot.zip
    # decompress them - silly since they'll just be re-compressed again, but it is what it is for now...
    xz -d clang.wasm.lzma
    xz -d lld.wasm.lzma

    cd ../../../../../

    echo "========================================"
    echo "Set Up Compilation Environment"
    echo "========================================"

    sudo apt-get -qq update
    sudo apt-get install -y build-essential cmake libpng-dev libcurl4-openssl-dev libsdl2-dev libsdl2-mixer-dev libsdl2-gfx-dev libsdl2-image-dev libsdl2-net-dev libsdl2-ttf-dev libmikmod-dev libbz2-dev libflac-dev libvorbis-dev libwebp-dev
    git clone https://github.com/emscripten-core/emsdk.git
    ./emsdk/emsdk install 3.1.48


    echo "========================================"
    echo "Build SplashKit WASM Libraries"
    echo "========================================"

    cd emsdk
    ./emsdk activate 3.1.48
    source ./emsdk_env.sh
    cd ../
    mkdir -p ./sko/SplashKitWasm/out/cxx/compiler/ # this one is due to a mistake in old CMakeLists, can be removed soon
    # build this as well...


    cd ./sko/SplashKitWasm/cmake/

    emcmake cmake -G "Unix Makefiles" -DENABLE_JS_BACKEND=ON -DENABLE_CPP_BACKEND=ON -DENABLE_FUNCTION_OVERLOADING=ON -DCOMPRESS_BACKENDS=ON .
    emmake make -j8

    cd ../../../

else

    echo "========================================"
    echo "Using Precompiled Binaries from Main"
    echo "========================================"

    cd ../

    # Rather than building, we'll just grab the compiled binaries from the main release.
    # To do this, we'll copy over all completely untracked files from it, which will correctly
    # handle if the PR has deleted files since branching from main.
    # Perhaps there's a cleaner way :)

    # first let's get a list of files _not_ to copy
    cd ./sko
    TRACKED_FILES=$(git log --pretty=format: --name-only --diff-filter=A -- Browser_IDE| sort - | sed '/^$/d')
    EXCLUDE_FILE=$(mktemp)
    echo "$TRACKED_FILES" | sed "s|^Browser_IDE||" > "$EXCLUDE_FILE"

    # add some explicit excludes
    echo "/codemirror-5.65.15" >> "$EXCLUDE_FILE"
    echo "/jszip" >> "$EXCLUDE_FILE"
    echo "/babel" >> "$EXCLUDE_FILE"
    echo "/split.js" >> "$EXCLUDE_FILE"
    echo "/mime" >> "$EXCLUDE_FILE"
    echo "/DemoProjects" >> "$EXCLUDE_FILE"
    echo "/node_modules" >> "$EXCLUDE_FILE"

    cd ../

    mkdir prebuilt
    cd prebuilt
    # Download main's latest release
    wget "https://github.com/$3/releases/download/branch%2Fmain/sko-static-site-branch_main.zip"
    unzip sko-static-site-branch_main.zip
    rm sko-static-site-branch_main.zip
    cd ../

    # copy in all the untracked files!
    rsync -av --progress --exclude-from="$EXCLUDE_FILE" "prebuilt/" "sko/Browser_IDE/"

fi


echo "========================================"
echo "Install Node Dependencies"
echo "========================================"
cd ./sko/Browser_IDE

npm install

cd ../../



echo "========================================"
echo "Re-Structure Static Site"
echo "========================================"
cd ./sko/Browser_IDE

# if changed, remember to update the explicit excludes above
mv node_modules/codemirror codemirror-5.65.15
mv node_modules/jszip/dist jszip
mv node_modules/@babel/standalone babel
mv node_modules/split.js/dist split.js
mv node_modules/mime/dist mime
rm -rf external/js-lzma/data
mv ../DemoProjects DemoProjects

cd ../

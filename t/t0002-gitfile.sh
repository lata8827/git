#!/bin/sh

test_description='.git file

Verify that plumbing commands work when .git is a file
'
. ./test-lib.sh

objpath() {
	echo "$1" | sed -e 's|\(..\)|\1/|'
}

test_expect_success 'initial setup' '
	REAL="$(pwd)/.real" &&
	mv .git "$REAL"
'

test_expect_success 'bad setup: invalid .git file format' '
	echo "gitdir $REAL" >.git &&
	test_must_fail git rev-parse 2>.err &&
	test_i18ngrep "invalid gitfile format" .err
'

test_expect_success 'bad setup: invalid .git file path' '
	echo "gitdir: $REAL.not" >.git &&
	test_must_fail git rev-parse 2>.err &&
	test_i18ngrep "not a git repository" .err
'

test_expect_success 'final setup + check rev-parse --git-dir' '
	echo "gitdir: $REAL" >.git &&
	test "$REAL" = "$(git rev-parse --git-dir)"
'

test_expect_success 'check hash-object' '
	echo "foo" >bar &&
	SHA=$(cat bar | git hash-object -w --stdin) &&
	test_path_is_file "$REAL/objects/$(objpath $SHA)"
'

test_expect_success 'check cat-file' '
	git cat-file blob $SHA >actual &&
	test_cmp bar actual
'

test_expect_success 'check update-index' '
	test_path_is_missing "$REAL/index" &&
	rm -f "$REAL/objects/$(objpath $SHA)" &&
	git update-index --add bar &&
	test_path_is_file "$REAL/index" &&
	test_path_is_file "$REAL/objects/$(objpath $SHA)"
'

test_expect_success 'check write-tree' '
	SHA=$(git write-tree) &&
	test_path_is_file "$REAL/objects/$(objpath $SHA)"
'

test_expect_success 'check commit-tree' '
	SHA=$(echo "commit bar" | git commit-tree $SHA) &&
	test_path_is_file "$REAL/objects/$(objpath $SHA)"
'

test_expect_success 'check rev-list' '
	echo $SHA >"$REAL/HEAD" &&
	test "$SHA" = "$(git rev-list HEAD)"
'

test_expect_success 'setup_git_dir twice in subdir' '
	git init sgd &&
	(
		cd sgd &&
		git config alias.lsfi ls-files &&
		mv .git .realgit &&
		echo "gitdir: .realgit" >.git &&
		mkdir subdir &&
		cd subdir &&
		>foo &&
		git add foo &&
		git lsfi >actual &&
		echo foo >expected &&
		test_cmp expected actual
	)
'

test_expect_success 'enter_repo non-strict mode' '
	test_create_repo enter_repo &&
	(
		cd enter_repo &&
		test_tick &&
		test_commit foo &&
		mv .git .realgit &&
		echo "gitdir: .realgit" >.git
	) &&
	git ls-remote enter_repo >actual &&
	cat >expected <<-\EOF &&
	946e985ab20de757ca5b872b16d64e92ff3803a9	HEAD
	946e985ab20de757ca5b872b16d64e92ff3803a9	refs/heads/master
	946e985ab20de757ca5b872b16d64e92ff3803a9	refs/tags/foo
	EOF
	test_cmp expected actual
'

test_expect_success 'enter_repo linked checkout' '
	(
		cd enter_repo &&
		git worktree add  ../foo refs/tags/foo
	) &&
	git ls-remote foo >actual &&
	cat >expected <<-\EOF &&
	946e985ab20de757ca5b872b16d64e92ff3803a9	HEAD
	946e985ab20de757ca5b872b16d64e92ff3803a9	refs/heads/master
	946e985ab20de757ca5b872b16d64e92ff3803a9	refs/tags/foo
	EOF
	test_cmp expected actual
'

test_expect_success 'enter_repo strict mode' '
	git ls-remote --upload-pack="git upload-pack --strict" foo/.git >actual &&
	cat >expected <<-\EOF &&
	946e985ab20de757ca5b872b16d64e92ff3803a9	HEAD
	946e985ab20de757ca5b872b16d64e92ff3803a9	refs/heads/master
	946e985ab20de757ca5b872b16d64e92ff3803a9	refs/tags/foo
	EOF
	test_cmp expected actual
'

test_done

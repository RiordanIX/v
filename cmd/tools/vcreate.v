// Copyright (c) 2019-2020 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

// This module follows a similar convention to Rust: `init` makes the
// structure of the program in the _current_ directory, while `new`
// makes the program structure in a _sub_ directory. Besides that, the
// functionality is essentially the same.
module main

import os
import cli

const (
	available_vcs = ['git', 'fossil', 'none']
)

struct Create {
mut:
	name        string
	description string
	path        string
	vcs         string
	quiet       bool
}

fn cerror(e string){
	eprintln('\nerror: $e')
}

fn vmod_content(name, desc string) string {
	return  [
		'#V Project#\n',
		'Module {',
		'	name: \'${name}\',',
		'	description: \'${desc}\',',
		'	dependencies: []',
		'}'
	].join('\n')
}

fn main_content() string {
	return [
		'module main\n',
		'fn main() {',
		'	println(\'Hello World !\')',
		'}'
	].join('\n')
}

fn gen_ignore(name string) string {
	return [
		'main',
		'$name',
		'*.so',
		'*.dll'
	].join('\n')
}

fn (c &Create)create_vmod() {
	mut vmod := os.create('${c.path}/v.mod') or {
		cerror(err)
		exit(1)
	}
	vmod.write(vmod_content(c.name, c.description))
	vmod.close()
}

fn (c &Create)create_main() {
	mut main := os.create('${c.path}/${c.name}.v') or {
		cerror(err)
		exit(2)
	}
	main.write(main_content())
	main.close()
}

// create_git_repo Create Git Repo and .gitignore file
fn (c &Create)create_git_repo() {
	os.exec('git init ${c.path}') or {
		cerror('Unable to create git repo at "${c.path}"')
		cerror('$err')
		exit(4)
	}
	if !os.exists('${c.path}/.gitignore') {
		mut fl := os.create('${c.path}/.gitignore') or {
			// We don't really need a .gitignore, it's just a nice-to-have
			return
		}
		fl.write(gen_ignore(c.name))
		fl.close()
	}
}

// create_fossil_rep Create a Fossil Repo and open it
fn (c &Create)create_fossil_repo() {
	if !os.exists(c.path) {
		// User can say wherever they want, but fossil won't create the directories.
		os.mkdir_all(c.path)
	}
	out := os.exec('fossil init ${c.path}/.fossil') or {
		cerror('Unable to create fossil repo at "${c.path}":')
		cerror('$err')
		exit(4)
	}
	if !c.quiet {
		println(out.output)
	}
	cwd := os.getwd() // just change temporarily
	os.chdir(c.path)
	os.exec('fossil open .fossil') or {
		cerror('Unable to open fossil repo "${c.path}/.fossil":')
		cerror('$err')
		exit(4)
	}
	os.chdir(cwd) // change back
}

// create_repo Create a repository for the specified vcs
fn (c &Create)create_repo() {
	// TODO add hg repo.
	match c.vcs {
		'git' { c.create_git_repo() }
		'fossil' { c.create_fossil_repo() }
		else { } // Should just be 'none'
	}
}

fn (c &Create)init_main() {
	// The file already exists, don't over-write anything.
	// Searching in the 'src' directory allows flexibility user module structure
	if os.exists('${c.name}.v') || os.exists('src/${c.name}.v') {
		return
	}
	mut main := os.create('${c.name}.v') or {
		cerror(err)
		exit(2)
	}
	main.write(main_content())
	main.close()
}

// parse_flags Generate the Create struct with defaults/passed args.
fn parse_flags(cmd cli.Command) Create {
	mut c := Create{}
	// this is a workaround because of a bug with initializing optionals
	q := cmd.flags.get_bool('quiet') or { panic(err) }
	p := cmd.flags.get_string('path') or { panic(err) }
	n := cmd.flags.get_string('name') or { panic(err) }
	d := cmd.flags.get_string('desc') or { panic(err) }
	v := cmd.flags.get_string('vcs') or { panic(err) }
	c.quiet = q
	c.path = p
	if c.path in ['./', '', '.'] {
		c.path = './' // This shouldn't be necessary, but it is.
	}
	c.name = n
	if c.name in ['./', '', '.'] {
		if c.path == './' { // Again, this shouldn't be necessary but it is.
			c.name = os.file_name(os.getwd())
		} else {
			c.name = c.path
		}
	}
	c.description = d
	c.vcs = v
	println("vcs: $c.vcs")
	println("desc: $c.description")
	println("name: $c.name")
	println("path: $c.path")
	println("quiet: $c.quiet")
	return c
}

fn new_mod(cmd cli.Command) {
	c := parse_flags(cmd)

	if os.is_dir(c.path) {
		cerror('${c.path} folder already exists')
		cerror('`v new` cannot create a module in a pre-existing directory')
		exit(3)
	}
	if !c.quiet {
		println('Initialising ...')
	}

	// Create repo first because it will also create the needed directories
	c.create_repo()
	c.create_vmod()
	c.create_main()
	if !c.quiet {
		println('Complete!')
	}
}

fn init_mod(cmd cli.Command) {
	c := parse_flags(cmd)
	if os.exists('${c.path}/v.mod') {
		cerror('`v init` cannot be run on existing V modules')
		exit(3)
	}
	// Create repo first because it will also create the needed directories
	c.create_repo()
	c.create_vmod()
	c.init_main()

	if !c.quiet {
		println("Change your module's description in `v.mod`")
		println('Complete!')
	}
}

fn main() {
	// Figure out if 'new' or 'init'
	mut path_desc := ''
	mut cmd := cli.Command{parent:0}
	mut path_required := false

	if 'new' == os.args[1] {
		cmd.name = 'v new'
		cmd.description = 'Create a new V module in a new directory'
		cmd.execute = new_mod
		path_desc = 'The directory to create the V module. Prompts the user if path is not given.'
		path_required = true
	} else if 'init' == os.args[1] {
		cmd.name = 'v init'
		cmd.description = 'Create a new V module in an existing directory'
		cmd.execute = init_mod
		path_desc = 'The directory to create the V module. Defaults to "./"'
	} else {
		cerror('Unknown command: ${os.args[1]}')
		exit(1)
	}

	cmd.add_flag(cli.Flag{
		flag: .bool
		required: false
		name: 'quiet'
		abbrev: 'q'
		description: 'No output printed to stdout'
		value: 'false'
	})
	cmd.add_flag(cli.Flag{
		flag: .string
		required: false
		name: 'vcs'
		description: 'Initialize a new repository for the given version control system. Available values are ${available_vcs}.'
		value: 'git'
	})
	cmd.add_flag(cli.Flag{
		flag: .string
		required: false
		name: 'desc'
		abbrev: 'd'
		description: 'The description for the module, to be put into v.mod. Defaults to blank'
		value: ''
	})
	cmd.add_flag(cli.Flag{
		flag: .string
		required: false
		name: 'name'
		description: 'Set the module name. Defaults to the path given'
	})
	cmd.add_flag(cli.Flag{
		flag: .string
		required: path_required // Only required for `v new`
		name: 'path'
		abbrev: 'p'
		description: path_desc
		value: './'
	})
	cmd.parse(os.args[1..])
}

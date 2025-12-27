use std::ffi::OsString;
use std::os::unix::process::CommandExt;
use std::process::Command;

use clap::{CommandFactory, FromArgMatches, Parser};
use snix_cli::find_command;
use tracing::debug;

#[derive(Parser)]
#[command(version, subcommand_required = true, allow_external_subcommands = true)]
struct Args {
    #[clap(flatten)]
    verbosity_flags: clap_verbosity_flag::Verbosity<clap_verbosity_flag::InfoLevel>,
}

const DEFAULT_LIBEXEC_PATH: Option<&str> = option_env!("SNIX_LIBEXEC_PATH");

fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let mut cmd = Args::command();
    let mut matches = cmd.clone().get_matches();
    let res = <Args as FromArgMatches>::from_arg_matches_mut(&mut matches)
        .map_err(|err| err.format(&mut cmd));
    let args = match res {
        Ok(s) => s,
        Err(e) => e.exit(),
    };

    let _tracing_handle = snix_tracing::TracingBuilder::default()
        .handle_verbosity_flags(&args.verbosity_flags)
        .build()?;

    if let Some((sub_cmd, ext_m)) = matches.subcommand() {
        let ext_args: Vec<_> = ext_m.get_many::<OsString>("").unwrap().collect();
        let path = find_command(sub_cmd, DEFAULT_LIBEXEC_PATH)?;
        let mut process = Command::new(path);
        process.args(&ext_args);
        debug!(program = ?process.get_program(), args = ?process.get_args().collect::<Vec<_>>(), "Executing command");
        Err(process.exec().into())
    } else {
        Ok(())
    }
}

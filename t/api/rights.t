#!/usr/bin/perl -w
# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC 
#                                          <jesse.com>
# 
# (Except where explicitly superseded by other copyright notices)
# 
# 
# LICENSE:
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/copyleft/gpl.html.
# 
# 
# CONTRIBUTION SUBMISSION POLICY:
# 
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
# 
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
# 
# END BPS TAGGED BLOCK }}}

use RT::Test; use Test::More tests => 26;
use RT;


use RT::I18N;
use strict;
no warnings 'once';

use RT::Model::Queue;
use RT::Model::ACE;
use RT::Model::User;
use RT::Model::Group;
use RT::Model::Ticket;


# clear all global right
my $acl = RT::Model::ACECollection->new(current_user => RT->system_user);
$acl->limit( column => 'right_name', operator => '!=', value => 'SuperUser' );
$acl->limit_to_object( RT->system );
while( my $ace = $acl->next ) {
	$ace->delete;
}

my $rand_name = "rights". int rand($$);
# create new queue to be shure we don't mess with rights
my $queue = RT::Model::Queue->new(current_user => RT->system_user);
my ($queue_id) = $queue->create( name => $rand_name);
ok( $queue_id, 'queue Created for rights tests' );

# new privileged user to check rights
my $user = RT::Model::User->new(current_user => RT->system_user );
my ($user_id) = $user->create( name => $rand_name,
			   email => $rand_name .'@localhost',
			   privileged => 1,
			   password => 'qwe123',
			 );
ok( !$user->has_right( Right => 'OwnTicket', Object => $queue ), "user can't own ticket" );
ok( !$user->has_right( Right => 'ReplyToTicket', Object => $queue ), "user can't reply to ticket" );

my $group = RT::Model::Group->new(current_user => RT->system_user );
ok( $group->loadQueueRoleGroup( Queue => $queue_id, Type=> 'Owner' ), "load queue owners role group" );
my $ace = RT::Model::ACE->new(current_user => RT->system_user );
my ($ace_id, $msg) = $group->principal_object->GrantRight( Right => 'ReplyToTicket', Object => $queue );
ok( $ace_id, "Granted queue owners role group with ReplyToTicket right: $msg" );
ok( $group->principal_object->has_right( Right => 'ReplyToTicket', Object => $queue ), "role group can reply to ticket" );
ok( !$user->has_right( Right => 'ReplyToTicket', Object => $queue ), "user can't reply to ticket" );

# new ticket
my $ticket = RT::Model::Ticket->new(current_user => RT->system_user);
my ($ticket_id) = $ticket->create( Queue => $queue_id, Subject => 'test');
ok( $ticket_id, 'new ticket Created' );
is( $ticket->Owner, RT->nobody->id, 'owner of the new ticket is nobody' );

my $status;
($status, $msg) = $user->principal_object->GrantRight( Object => $queue, Right => 'OwnTicket' );
ok( $status, "successfuly granted right: $msg" );
ok( $user->has_right( Right => 'OwnTicket', Object => $queue ), "user can own ticket" );

($status, $msg) = $ticket->set_Owner( $user_id );
ok( $status, "successfuly set owner: $msg" );
is( $ticket->Owner, $user_id, "set correct owner" );

ok( $user->has_right( Right => 'ReplyToTicket', Object => $ticket ), "user is owner and can reply to ticket" );

# Testing of equiv_objects
$group = RT::Model::Group->new(current_user => RT->system_user );
ok( $group->loadQueueRoleGroup( Queue => $queue_id, Type=> 'AdminCc' ), "load queue AdminCc role group" );
$ace = RT::Model::ACE->new(current_user => RT->system_user );
($ace_id, $msg) = $group->principal_object->GrantRight( Right => 'ModifyTicket', Object => $queue );
ok( $ace_id, "Granted queue AdminCc role group with ModifyTicket right: $msg" );
ok( $group->principal_object->has_right( Right => 'ModifyTicket', Object => $queue ), "role group can modify ticket" );
ok( !$user->has_right( Right => 'ModifyTicket', Object => $ticket ), "user is not AdminCc and can't modify ticket" );
($status, $msg) = $ticket->AddWatcher(Type => 'AdminCc', principal_id => $user->principal_id);
ok( $status, "successfuly added user as AdminCc");
ok( $user->has_right( Right => 'ModifyTicket', Object => $ticket ), "user is AdminCc and can modify ticket" );

my $ticket2 = RT::Model::Ticket->new(current_user => RT->system_user);
my ($ticket2_id) = $ticket2->create( Queue => $queue_id, Subject => 'test2');
ok( $ticket2_id, 'new ticket Created' );
ok( !$user->has_right( Right => 'ModifyTicket', Object => $ticket2 ), "user is not AdminCc and can't modify ticket2" );

# now we can finally test equiv_objects
my $equiv = [ $ticket ];
ok( $user->has_right( Right => 'ModifyTicket', Object => $ticket2, equiv_objects => $equiv ), 
    "user is not AdminCc but can modify ticket2 because of equiv_objects" );

# the first a third test below are the same, so they should both pass
my $equiv2 = [];
ok( !$user->has_right( Right => 'ModifyTicket', Object => $ticket2, equiv_objects => $equiv2 ), 
    "user is not AdminCc and can't modify ticket2" );
ok( $user->has_right( Right => 'ModifyTicket', Object => $ticket, equiv_objects => $equiv2 ), 
    "user is AdminCc and can modify ticket" );
ok( !$user->has_right( Right => 'ModifyTicket', Object => $ticket2, equiv_objects => $equiv2 ), 
    "user is not AdminCc and can't modify ticket2 (same question different answer)" );
